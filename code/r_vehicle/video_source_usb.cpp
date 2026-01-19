/*
    Ruby Licence
    Copyright (c) 2020-2025 Petru Soroaga petrusoroaga@yahoo.com
    All rights reserved.
    
    USB Thermal Camera Video Source Module
*/

#include "../base/base.h"
#include "../base/config.h"
#include "../base/shared_mem.h"
#include "../base/hardware_procs.h"
#include "../base/parser_h264.h"
#include "../base/utils.h"
#include "../common/string_utils.h"

#include <pthread.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/ioctl.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <poll.h>
#include <signal.h>

#ifdef __linux__
#include <linux/videodev2.h>
#endif

#include "video_source_usb.h"
#include "video_sources.h"
#include "shared_vars.h"
#include "timers.h"

// ============ RING BUFFER STRUCTURE ============

typedef struct {
    u8 data[USB_CAMERA_MAX_NAL_SIZE];
    int size;
    u32 uTimestamp;
    u32 uNALType;
    bool bIsStartNAL;
    bool bIsEndNAL;
    bool bValid;
} usb_nal_buffer_t;

typedef struct {
    usb_nal_buffer_t buffers[USB_CAMERA_RING_BUFFER_COUNT];
    int iWriteIndex;
    int iReadIndex;
    int iCount;
    pthread_mutex_t mutex;
} usb_ring_buffer_t;

// ============ GLOBAL VARIABLES ============

static pthread_t s_pThreadUSBCapture;
static bool s_bUSBCaptureThreadRunning = false;
static volatile bool s_bUSBCaptureThreadStop = false;

static pid_t s_iFFMpegPid = -1;
static int s_iFFMpegPipeReadFd = -1;

static usb_ring_buffer_t s_RingBuffer;
static u8 s_uTempReadBuffer[USB_CAMERA_BUFFER_SIZE];

static ParserH264 s_ParserH264USB;
static usb_camera_state_t s_USBCameraState = USB_CAMERA_STATE_STOPPED;
static u32 s_uUSBStartTime = 0;

static u32 s_uCurrentBitrate = 0;
static int s_iCurrentKeyframeMs = 0;

// Last read NAL info
static u32 s_uLastNALType = 0;
static bool s_bLastReadIsStartNAL = false;
static bool s_bLastReadIsEndNAL = false;
static bool s_bLastReadIsSingleNAL = false;
static int s_iLastReadBufferIndex = -1;

// Statistics
static u32 s_uDebugTimeLastUSBVideoInputCheck = 0;
static u32 s_uDebugUSBInputBytes = 0;
static u32 s_uDebugUSBInputReads = 0;
static u32 s_uTimeLastHealthCheck = 0;
static int s_iConsecutiveReadErrors = 0;

// ============ RING BUFFER FUNCTIONS ============

static void _ring_buffer_init()
{
    pthread_mutex_init(&s_RingBuffer.mutex, NULL);
    s_RingBuffer.iWriteIndex = 0;
    s_RingBuffer.iReadIndex = 0;
    s_RingBuffer.iCount = 0;
    for (int i = 0; i < USB_CAMERA_RING_BUFFER_COUNT; i++)
    {
        s_RingBuffer.buffers[i].size = 0;
        s_RingBuffer.buffers[i].bValid = false;
    }
}

static void _ring_buffer_destroy()
{
    pthread_mutex_destroy(&s_RingBuffer.mutex);
}

static bool _ring_buffer_write(u8* pData, int iSize, u32 uNALType, 
                                bool bIsStart, bool bIsEnd, u32 uTimestamp)
{
    if (iSize <= 0 || iSize > USB_CAMERA_MAX_NAL_SIZE)
        return false;
        
    pthread_mutex_lock(&s_RingBuffer.mutex);
    
    if (s_RingBuffer.iCount >= USB_CAMERA_RING_BUFFER_COUNT)
    {
        // Buffer full - overwrite oldest
        s_RingBuffer.iReadIndex = (s_RingBuffer.iReadIndex + 1) % USB_CAMERA_RING_BUFFER_COUNT;
        s_RingBuffer.iCount--;
    }
    
    usb_nal_buffer_t* pBuf = &s_RingBuffer.buffers[s_RingBuffer.iWriteIndex];
    memcpy(pBuf->data, pData, iSize);
    pBuf->size = iSize;
    pBuf->uNALType = uNALType;
    pBuf->bIsStartNAL = bIsStart;
    pBuf->bIsEndNAL = bIsEnd;
    pBuf->uTimestamp = uTimestamp;
    pBuf->bValid = true;
    
    s_RingBuffer.iWriteIndex = (s_RingBuffer.iWriteIndex + 1) % USB_CAMERA_RING_BUFFER_COUNT;
    s_RingBuffer.iCount++;
    
    pthread_mutex_unlock(&s_RingBuffer.mutex);
    return true;
}

static usb_nal_buffer_t* _ring_buffer_read()
{
    pthread_mutex_lock(&s_RingBuffer.mutex);
    
    if (s_RingBuffer.iCount <= 0)
    {
        pthread_mutex_unlock(&s_RingBuffer.mutex);
        return NULL;
    }
    
    usb_nal_buffer_t* pBuf = &s_RingBuffer.buffers[s_RingBuffer.iReadIndex];
    s_iLastReadBufferIndex = s_RingBuffer.iReadIndex;
    s_RingBuffer.iReadIndex = (s_RingBuffer.iReadIndex + 1) % USB_CAMERA_RING_BUFFER_COUNT;
    s_RingBuffer.iCount--;
    
    pthread_mutex_unlock(&s_RingBuffer.mutex);
    return pBuf;
}

static void _ring_buffer_clear()
{
    pthread_mutex_lock(&s_RingBuffer.mutex);
    s_RingBuffer.iWriteIndex = 0;
    s_RingBuffer.iReadIndex = 0;
    s_RingBuffer.iCount = 0;
    for (int i = 0; i < USB_CAMERA_RING_BUFFER_COUNT; i++)
        s_RingBuffer.buffers[i].bValid = false;
    pthread_mutex_unlock(&s_RingBuffer.mutex);
}

// ============ HELPER FUNCTIONS ============

static bool _video_source_usb_check_device_available(const char* szDevicePath)
{
    if (NULL == szDevicePath)
        szDevicePath = USB_CAMERA_DEFAULT_DEVICE;
        
#ifdef __linux__
    int fd = open(szDevicePath, O_RDWR | O_NONBLOCK);
    if (fd < 0)
    {
        log_line("[VideoSourceUSB] Device %s not found: %s", szDevicePath, strerror(errno));
        return false;
    }
    
    // Validate V4L2 capabilities
    struct v4l2_capability cap;
    memset(&cap, 0, sizeof(cap));
    
    if (ioctl(fd, VIDIOC_QUERYCAP, &cap) < 0)
    {
        log_line("[VideoSourceUSB] Device %s is not a V4L2 device", szDevicePath);
        close(fd);
        return false;
    }
    
    if (!(cap.capabilities & V4L2_CAP_VIDEO_CAPTURE))
    {
        log_line("[VideoSourceUSB] Device %s doesn't support video capture", szDevicePath);
        close(fd);
        return false;
    }
    
    log_line("[VideoSourceUSB] Found V4L2 device: %s (%s)", cap.card, cap.driver);
    close(fd);
    return true;
#else
    return false;
#endif
}

static pid_t _start_ffmpeg_process(int* pPipeReadFd)
{
    if (NULL == pPipeReadFd)
        return -1;
        
    int pipefd[2];
    if (pipe(pipefd) < 0)
    {
        log_error_and_alarm("[VideoSourceUSB] Failed to create pipe: %s", strerror(errno));
        return -1;
    }
    
    pid_t pid = fork();
    if (pid < 0)
    {
        log_error_and_alarm("[VideoSourceUSB] Fork failed: %s", strerror(errno));
        close(pipefd[0]);
        close(pipefd[1]);
        return -1;
    }
    
    if (pid == 0)
    {
        // Child process - FFmpeg
        close(pipefd[0]); // Close read end
        
        // Redirect stdout to pipe
        dup2(pipefd[1], STDOUT_FILENO);
        close(pipefd[1]);
        
        // Redirect stderr to /dev/null
        int devnull = open("/dev/null", O_WRONLY);
        if (devnull >= 0)
        {
            dup2(devnull, STDERR_FILENO);
            close(devnull);
        }
        
        // Get video parameters from model if available
        int iWidth = USB_CAMERA_DEFAULT_WIDTH;
        int iHeight = USB_CAMERA_DEFAULT_HEIGHT;
        int iFPS = USB_CAMERA_DEFAULT_FPS;
        
        if (NULL != g_pCurrentModel)
        {
            if (g_pCurrentModel->video_params.iVideoWidth > 0)
                iWidth = g_pCurrentModel->video_params.iVideoWidth;
            if (g_pCurrentModel->video_params.iVideoHeight > 0)
                iHeight = g_pCurrentModel->video_params.iVideoHeight;
            if (g_pCurrentModel->video_params.iVideoFPS > 0)
                iFPS = g_pCurrentModel->video_params.iVideoFPS;
        }
        
        char szResolution[32];
        snprintf(szResolution, sizeof(szResolution), "%dx%d", iWidth, iHeight);
        
        char szFPS[16];
        snprintf(szFPS, sizeof(szFPS), "%d", iFPS);
        
        char szBitrate[32];
        snprintf(szBitrate, sizeof(szBitrate), "%u", s_uCurrentBitrate);
        
        char szKeyframe[16];
        int iKeyframeFrames = (s_iCurrentKeyframeMs * iFPS) / 1000;
        if (iKeyframeFrames < 1) iKeyframeFrames = iFPS * 2; // Default 2 seconds
        snprintf(szKeyframe, sizeof(szKeyframe), "%d", iKeyframeFrames);
        
        // Execute FFmpeg
        execlp("ffmpeg", "ffmpeg",
               "-f", "v4l2",
               "-input_format", "mjpeg",   // Most USB cameras support MJPEG
               "-video_size", szResolution,
               "-framerate", szFPS,
               "-i", USB_CAMERA_DEFAULT_DEVICE,
               "-c:v", "libx264",
               "-preset", "ultrafast",
               "-tune", "zerolatency",
               "-b:v", szBitrate,
               "-maxrate", szBitrate,
               "-bufsize", szBitrate,
               "-g", szKeyframe,
               "-keyint_min", szKeyframe,
               "-sc_threshold", "0",
               "-profile:v", "baseline",
               "-level", "4.0",
               "-pix_fmt", "yuv420p",
               "-f", "h264",
               "-",
               (char*)NULL);
        
        // If execlp returns, it failed
        log_error_and_alarm("[VideoSourceUSB] Failed to execute ffmpeg: %s", strerror(errno));
        _exit(1);
    }
    
    // Parent process
    close(pipefd[1]); // Close write end
    
    // Set non-blocking
    int flags = fcntl(pipefd[0], F_GETFL, 0);
    fcntl(pipefd[0], F_SETFL, flags | O_NONBLOCK);
    
    *pPipeReadFd = pipefd[0];
    
    log_line("[VideoSourceUSB] Started FFmpeg process, PID: %d", (int)pid);
    return pid;
}

static void _stop_ffmpeg_process()
{
    if (s_iFFMpegPid > 0)
    {
        log_line("[VideoSourceUSB] Stopping FFmpeg process PID: %d", (int)s_iFFMpegPid);
        
        // Send SIGTERM first
        kill(s_iFFMpegPid, SIGTERM);
        
        // Wait up to 500ms
        for (int i = 0; i < 10; i++)
        {
            int status;
            pid_t result = waitpid(s_iFFMpegPid, &status, WNOHANG);
            if (result == s_iFFMpegPid)
            {
                log_line("[VideoSourceUSB] FFmpeg process terminated gracefully");
                break;
            }
            hardware_sleep_ms(50);
        }
        
        // Force kill if still running
        if (kill(s_iFFMpegPid, 0) == 0)
        {
            log_line("[VideoSourceUSB] Force killing FFmpeg process");
            kill(s_iFFMpegPid, SIGKILL);
            waitpid(s_iFFMpegPid, NULL, 0);
        }
        
        s_iFFMpegPid = -1;
    }
    
    if (s_iFFMpegPipeReadFd >= 0)
    {
        close(s_iFFMpegPipeReadFd);
        s_iFFMpegPipeReadFd = -1;
    }
}

// ============ CAPTURE THREAD ============

static void* _video_source_usb_capture_thread(void* arg)
{
    log_line("[VideoSourceUSB] Capture thread started");
    hw_log_current_thread_attributes("usb capture");
    
    u8 uNALStartCode[4] = {0x00, 0x00, 0x00, 0x01};
    u8 uAccumulatedBuffer[USB_CAMERA_MAX_NAL_SIZE];
    int iAccumulatedSize = 0;
    bool bInNAL = false;
    
    while (!s_bUSBCaptureThreadStop)
    {
        if (s_iFFMpegPipeReadFd < 0)
        {
            hardware_sleep_ms(100);
            continue;
        }
        
        // Poll for data
        struct pollfd pfd;
        pfd.fd = s_iFFMpegPipeReadFd;
        pfd.events = POLLIN;
        
        int pollResult = poll(&pfd, 1, 10); // 10ms timeout
        
        if (pollResult < 0)
        {
            if (errno != EINTR)
            {
                log_error_and_alarm("[VideoSourceUSB] Poll error: %s", strerror(errno));
                s_iConsecutiveReadErrors++;
            }
            continue;
        }
        
        if (pollResult == 0)
            continue; // Timeout, no data
            
        if (!(pfd.revents & POLLIN))
        {
            if (pfd.revents & (POLLERR | POLLHUP))
            {
                log_error_and_alarm("[VideoSourceUSB] Pipe error/hangup");
                s_USBCameraState = USB_CAMERA_STATE_ERROR;
                break;
            }
            continue;
        }
        
        // Read data
        ssize_t bytesRead = read(s_iFFMpegPipeReadFd, s_uTempReadBuffer, 
                                  sizeof(s_uTempReadBuffer));
        
        if (bytesRead < 0)
        {
            if (errno == EAGAIN || errno == EWOULDBLOCK)
                continue;
            log_error_and_alarm("[VideoSourceUSB] Read error: %s", strerror(errno));
            s_iConsecutiveReadErrors++;
            continue;
        }
        
        if (bytesRead == 0)
        {
            log_line("[VideoSourceUSB] FFmpeg pipe closed (EOF)");
            s_USBCameraState = USB_CAMERA_STATE_ERROR;
            break;
        }
        
        s_iConsecutiveReadErrors = 0;
        s_uDebugUSBInputBytes += bytesRead;
        s_uDebugUSBInputReads++;
        
        // Parse H264 stream to find NAL units
        for (ssize_t i = 0; i < bytesRead; i++)
        {
            // Look for NAL start code (0x00 0x00 0x00 0x01 or 0x00 0x00 0x01)
            if (i + 3 < bytesRead &&
                s_uTempReadBuffer[i] == 0x00 &&
                s_uTempReadBuffer[i+1] == 0x00)
            {
                bool bFoundStartCode = false;
                int iStartCodeLen = 0;
                
                if (s_uTempReadBuffer[i+2] == 0x01)
                {
                    bFoundStartCode = true;
                    iStartCodeLen = 3;
                }
                else if (i + 4 < bytesRead &&
                         s_uTempReadBuffer[i+2] == 0x00 &&
                         s_uTempReadBuffer[i+3] == 0x01)
                {
                    bFoundStartCode = true;
                    iStartCodeLen = 4;
                }
                
                if (bFoundStartCode)
                {
                    // Save previous NAL if any
                    if (bInNAL && iAccumulatedSize > 4)
                    {
                        u8 uNALType = uAccumulatedBuffer[4] & 0x1F;
                        bool bIsKeyframe = (uNALType == 5);
                        bool bIsSlice = (uNALType == 1 || uNALType == 5);
                        
                        _ring_buffer_write(uAccumulatedBuffer, iAccumulatedSize,
                                          uNALType, bIsSlice, bIsSlice,
                                          get_current_timestamp_ms());
                    }
                    
                    // Start new NAL with 4-byte start code
                    memcpy(uAccumulatedBuffer, uNALStartCode, 4);
                    iAccumulatedSize = 4;
                    bInNAL = true;
                    
                    i += iStartCodeLen - 1; // -1 because loop will increment
                    continue;
                }
            }
            
            // Accumulate data
            if (bInNAL && iAccumulatedSize < USB_CAMERA_MAX_NAL_SIZE)
            {
                uAccumulatedBuffer[iAccumulatedSize++] = s_uTempReadBuffer[i];
            }
        }
    }
    
    // Flush any remaining data
    if (bInNAL && iAccumulatedSize > 4)
    {
        u8 uNALType = uAccumulatedBuffer[4] & 0x1F;
        _ring_buffer_write(uAccumulatedBuffer, iAccumulatedSize,
                          uNALType, true, true, get_current_timestamp_ms());
    }
    
    s_bUSBCaptureThreadRunning = false;
    log_line("[VideoSourceUSB] Capture thread ended");
    return NULL;
}

// ============ PUBLIC FUNCTIONS ============

u32 video_source_usb_start_program(u32 uOverwriteInitialBitrate, 
                                    int iOverwriteInitialKFMs, 
                                    int iOverwriteInitialQPDelta, 
                                    int* pInitialKFSet)
{
    log_line("[VideoSourceUSB] Starting USB camera capture...");
    
    if (!_video_source_usb_check_device_available(USB_CAMERA_DEFAULT_DEVICE))
    {
        log_error_and_alarm("[VideoSourceUSB] USB camera device not available");
        s_USBCameraState = USB_CAMERA_STATE_ERROR;
        return 0;
    }
    
    // Initialize parameters
    s_uCurrentBitrate = uOverwriteInitialBitrate;
    if (s_uCurrentBitrate == 0)
        s_uCurrentBitrate = DEFAULT_VIDEO_BITRATE;
        
    s_iCurrentKeyframeMs = iOverwriteInitialKFMs;
    if (s_iCurrentKeyframeMs <= 0)
        s_iCurrentKeyframeMs = 2000; // Default 2 seconds
    
    log_line("[VideoSourceUSB] Settings: Bitrate=%.2f Mbps, Keyframe=%d ms",
             (float)s_uCurrentBitrate / 1000000.0, s_iCurrentKeyframeMs);
    
    // Initialize ring buffer
    _ring_buffer_init();
    s_ParserH264USB.init();
    
    // Start FFmpeg process
    s_USBCameraState = USB_CAMERA_STATE_STARTING;
    s_iFFMpegPid = _start_ffmpeg_process(&s_iFFMpegPipeReadFd);
    
    if (s_iFFMpegPid < 0)
    {
        log_error_and_alarm("[VideoSourceUSB] Failed to start FFmpeg");
        s_USBCameraState = USB_CAMERA_STATE_ERROR;
        return 0;
    }
    
    // Wait a bit for FFmpeg to initialize
    hardware_sleep_ms(200);
    
    // Start capture thread
    s_bUSBCaptureThreadStop = false;
    s_bUSBCaptureThreadRunning = true;
    
    pthread_attr_t attr;
    pthread_attr_init(&attr);
    
    if (pthread_create(&s_pThreadUSBCapture, &attr, 
                       _video_source_usb_capture_thread, NULL) != 0)
    {
        log_error_and_alarm("[VideoSourceUSB] Failed to create capture thread");
        _stop_ffmpeg_process();
        s_bUSBCaptureThreadRunning = false;
        s_USBCameraState = USB_CAMERA_STATE_ERROR;
        pthread_attr_destroy(&attr);
        return 0;
    }
    
    pthread_attr_destroy(&attr);
    
    s_uUSBStartTime = get_current_timestamp_ms();
    s_USBCameraState = USB_CAMERA_STATE_RUNNING;
    s_iConsecutiveReadErrors = 0;
    
    if (pInitialKFSet)
        *pInitialKFSet = s_iCurrentKeyframeMs;
    
    log_line("[VideoSourceUSB] USB camera started successfully");
    return s_uCurrentBitrate;
}

void video_source_usb_stop_program()
{
    log_line("[VideoSourceUSB] Stopping USB camera capture...");
    
    s_bUSBCaptureThreadStop = true;
    
    // Wait for thread to finish
    if (s_bUSBCaptureThreadRunning)
    {
        int iWaitCount = 0;
        while (s_bUSBCaptureThreadRunning && iWaitCount < 50)
        {
            hardware_sleep_ms(10);
            iWaitCount++;
        }
        
        if (s_bUSBCaptureThreadRunning)
        {
            log_line("[VideoSourceUSB] Thread still running, cancelling...");
            pthread_cancel(s_pThreadUSBCapture);
        }
        
        pthread_join(s_pThreadUSBCapture, NULL);
        s_bUSBCaptureThreadRunning = false;
    }
    
    _stop_ffmpeg_process();
    _ring_buffer_clear();
    _ring_buffer_destroy();
    
    s_USBCameraState = USB_CAMERA_STATE_STOPPED;
    s_uUSBStartTime = 0;
    
    log_line("[VideoSourceUSB] USB camera stopped");
}

u32 video_source_usb_get_program_start_time()
{
    return s_uUSBStartTime;
}

u8* video_source_usb_read(int* piReadSize, bool bAsync, u32* puOutTimeDataAvailable)
{
    if (piReadSize)
        *piReadSize = 0;
        
    if (s_USBCameraState != USB_CAMERA_STATE_RUNNING)
        return NULL;
    
    usb_nal_buffer_t* pBuf = _ring_buffer_read();
    if (NULL == pBuf || !pBuf->bValid)
        return NULL;
    
    // Update last read info
    s_uLastNALType = pBuf->uNALType;
    s_bLastReadIsStartNAL = pBuf->bIsStartNAL;
    s_bLastReadIsEndNAL = pBuf->bIsEndNAL;
    s_bLastReadIsSingleNAL = true;
    
    if (piReadSize)
        *piReadSize = pBuf->size;
    if (puOutTimeDataAvailable)
        *puOutTimeDataAvailable = pBuf->uTimestamp;
    
    return pBuf->data;
}

void video_source_usb_clear_input_buffers()
{
    log_line("[VideoSourceUSB] Clearing input buffers");
    _ring_buffer_clear();
    s_ParserH264USB.reset();
}

bool video_source_usb_last_read_is_single_nal()
{
    return s_bLastReadIsSingleNAL;
}

bool video_source_usb_last_read_is_start_nal()
{
    return s_bLastReadIsStartNAL;
}

bool video_source_usb_last_read_is_end_nal()
{
    return s_bLastReadIsEndNAL;
}

u32 video_source_usb_get_last_nal_type()
{
    return s_uLastNALType;
}

void video_source_usb_apply_all_parameters()
{
    log_line("[VideoSourceUSB] Applying all parameters (restart required for changes)");
    
    // For USB camera, changing parameters requires restarting FFmpeg
    // This is called when settings change
    if (s_USBCameraState == USB_CAMERA_STATE_RUNNING)
    {
        // Could implement restart logic here if dynamic changes needed
        // For now, just log that a restart would be required
    }
}

int video_source_usb_get_audio_data(u8* pOutputBuffer, int iMaxToRead)
{
    // Thermal cameras typically don't have audio
    return 0;
}

void video_source_usb_clear_audio_buffers()
{
    // No audio for USB thermal cameras
}

bool video_source_usb_periodic_health_checks()
{
    if (s_USBCameraState == USB_CAMERA_STATE_STOPPED)
        return true;
        
    u32 uNow = get_current_timestamp_ms();
    
    // Log statistics periodically
    if (uNow > s_uDebugTimeLastUSBVideoInputCheck + 5000)
    {
        u32 uDeltaMs = uNow - s_uDebugTimeLastUSBVideoInputCheck;
        if (uDeltaMs > 0)
        {
            float fBitrateMbps = (float)(s_uDebugUSBInputBytes * 8) / (float)uDeltaMs / 1000.0;
            log_line("[VideoSourceUSB] Stats: %.2f Mbps, %u reads in %u ms",
                     fBitrateMbps, s_uDebugUSBInputReads, uDeltaMs);
        }
        s_uDebugUSBInputBytes = 0;
        s_uDebugUSBInputReads = 0;
        s_uDebugTimeLastUSBVideoInputCheck = uNow;
    }
    
    // Check for errors
    if (s_USBCameraState == USB_CAMERA_STATE_ERROR)
    {
        log_error_and_alarm("[VideoSourceUSB] Camera in error state, attempting restart...");
        
        // Attempt restart
        video_source_usb_stop_program();
        hardware_sleep_ms(500);
        
        u32 uBitrate = video_source_usb_start_program(s_uCurrentBitrate, 
                                                       s_iCurrentKeyframeMs, 
                                                       0, NULL);
        return (uBitrate > 0);
    }
    
    // Check if FFmpeg is still running
    if (s_iFFMpegPid > 0)
    {
        int status;
        pid_t result = waitpid(s_iFFMpegPid, &status, WNOHANG);
        if (result == s_iFFMpegPid)
        {
            log_error_and_alarm("[VideoSourceUSB] FFmpeg process died unexpectedly");
            s_USBCameraState = USB_CAMERA_STATE_ERROR;
            return false;
        }
    }
    
    // Check for device availability
    if (uNow > s_uTimeLastHealthCheck + 10000)
    {
        s_uTimeLastHealthCheck = uNow;
        if (!_video_source_usb_check_device_available(USB_CAMERA_DEFAULT_DEVICE))
        {
            log_error_and_alarm("[VideoSourceUSB] USB device lost!");
            s_USBCameraState = USB_CAMERA_STATE_DEVICE_LOST;
            return false;
        }
    }
    
    // Check for excessive read errors
    if (s_iConsecutiveReadErrors > 100)
    {
        log_error_and_alarm("[VideoSourceUSB] Too many consecutive read errors");
        s_USBCameraState = USB_CAMERA_STATE_ERROR;
        return false;
    }
    
    return true;
}

bool video_source_usb_is_available()
{
    return _video_source_usb_check_device_available(USB_CAMERA_DEFAULT_DEVICE);
}

usb_camera_state_t video_source_usb_get_state()
{
    return s_USBCameraState;
}
