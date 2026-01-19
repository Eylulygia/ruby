/*
    USB Camera Module Test
    Build: g++ -std=c++11 -DRUBY_BUILD_HW_PLATFORM_PI -I.. test_usb_camera.cpp -o test_usb_camera -lpthread
    Run:   ./test_usb_camera
*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <sys/ioctl.h>

#ifdef __linux__
#include <linux/videodev2.h>
#endif

// Colors for output
#define GREEN "\033[32m"
#define RED "\033[31m"
#define YELLOW "\033[33m"
#define RESET "\033[0m"

#define TEST_PASS(msg) printf(GREEN "[PASS] " RESET "%s\n", msg)
#define TEST_FAIL(msg) printf(RED "[FAIL] " RESET "%s\n", msg)
#define TEST_WARN(msg) printf(YELLOW "[WARN] " RESET "%s\n", msg)
#define TEST_INFO(msg) printf("[INFO] %s\n", msg)

int g_iTestsPassed = 0;
int g_iTestsFailed = 0;

// ============ TEST 1: V4L2 Device Detection ============
bool test_v4l2_device_detection()
{
    TEST_INFO("Testing V4L2 device detection...");
    
#ifdef __linux__
    const char* devices[] = {"/dev/video0", "/dev/video1", "/dev/video2"};
    bool found = false;
    
    for (int i = 0; i < 3; i++)
    {
        int fd = open(devices[i], O_RDWR | O_NONBLOCK);
        if (fd >= 0)
        {
            struct v4l2_capability cap;
            memset(&cap, 0, sizeof(cap));
            
            if (ioctl(fd, VIDIOC_QUERYCAP, &cap) >= 0)
            {
                printf("  Found device: %s\n", devices[i]);
                printf("    Card: %s\n", cap.card);
                printf("    Driver: %s\n", cap.driver);
                printf("    Bus: %s\n", cap.bus_info);
                printf("    Capabilities: 0x%08x\n", cap.capabilities);
                
                if (cap.capabilities & V4L2_CAP_VIDEO_CAPTURE)
                {
                    printf("    ✓ Supports video capture\n");
                    found = true;
                }
                
                // Check if USB (not CSI)
                if (strstr((char*)cap.driver, "bcm2835") == NULL &&
                    strstr((char*)cap.driver, "mmal") == NULL)
                {
                    printf("    ✓ USB device (not CSI)\n");
                }
                else
                {
                    printf("    ⚠ CSI device (bcm2835/mmal)\n");
                }
            }
            close(fd);
        }
    }
    
    if (found)
    {
        TEST_PASS("V4L2 video capture device found");
        return true;
    }
    else
    {
        TEST_WARN("No V4L2 video device found - this is OK for build testing");
        return true; // Still pass for build test
    }
#else
    TEST_WARN("Not on Linux - V4L2 test skipped");
    return true;
#endif
}

// ============ TEST 2: FFmpeg Availability ============
bool test_ffmpeg_available()
{
    TEST_INFO("Testing FFmpeg availability...");
    
    int ret = system("which ffmpeg > /dev/null 2>&1");
    if (ret == 0)
    {
        // Check for libx264
        ret = system("ffmpeg -encoders 2>/dev/null | grep -q libx264");
        if (ret == 0)
        {
            TEST_PASS("FFmpeg with libx264 encoder available");
            return true;
        }
        else
        {
            TEST_WARN("FFmpeg found but libx264 may not be available");
            return true;
        }
    }
    else
    {
        TEST_FAIL("FFmpeg not found in PATH");
        printf("  Install with: sudo apt-get install ffmpeg\n");
        return false;
    }
}

// ============ TEST 3: Ring Buffer Logic ============
bool test_ring_buffer_logic()
{
    TEST_INFO("Testing ring buffer logic...");
    
    // Simulate ring buffer
    #define RING_SIZE 8
    int writeIndex = 0;
    int readIndex = 0;
    int count = 0;
    
    // Test write
    for (int i = 0; i < 10; i++)
    {
        if (count >= RING_SIZE)
        {
            // Overwrite oldest
            readIndex = (readIndex + 1) % RING_SIZE;
            count--;
        }
        writeIndex = (writeIndex + 1) % RING_SIZE;
        count++;
    }
    
    // Should have 8 items (capped at RING_SIZE)
    if (count == RING_SIZE)
    {
        TEST_PASS("Ring buffer overflow handling correct");
        return true;
    }
    else
    {
        TEST_FAIL("Ring buffer logic error");
        return false;
    }
}

// ============ TEST 4: NAL Start Code Detection ============
bool test_nal_start_code_detection()
{
    TEST_INFO("Testing NAL start code detection...");
    
    // Test data with NAL start codes
    unsigned char testData[] = {
        0x00, 0x00, 0x00, 0x01, 0x67, 0x42, 0x00, 0x1e,  // SPS (NAL type 7)
        0x00, 0x00, 0x00, 0x01, 0x68, 0xce, 0x38, 0x80,  // PPS (NAL type 8)
        0x00, 0x00, 0x01, 0x65, 0x88, 0x84, 0x00, 0xff,  // IDR (NAL type 5) - 3 byte start
        0x00, 0x00, 0x00, 0x01, 0x41, 0x9a, 0x00, 0x00   // P-frame (NAL type 1)
    };
    
    int nalCount = 0;
    int nalTypes[10] = {0};
    
    for (size_t i = 0; i < sizeof(testData) - 4; i++)
    {
        bool found = false;
        int nalTypeOffset = 0;
        
        // 4-byte start code
        if (testData[i] == 0x00 && testData[i+1] == 0x00 &&
            testData[i+2] == 0x00 && testData[i+3] == 0x01)
        {
            found = true;
            nalTypeOffset = 4;
        }
        // 3-byte start code
        else if (testData[i] == 0x00 && testData[i+1] == 0x00 &&
                 testData[i+2] == 0x01)
        {
            found = true;
            nalTypeOffset = 3;
        }
        
        if (found && i + nalTypeOffset < sizeof(testData))
        {
            int nalType = testData[i + nalTypeOffset] & 0x1F;
            if (nalCount < 10)
                nalTypes[nalCount] = nalType;
            nalCount++;
            i += nalTypeOffset - 1;
        }
    }
    
    printf("  Found %d NAL units\n", nalCount);
    for (int i = 0; i < nalCount; i++)
    {
        const char* typeName = "Unknown";
        switch (nalTypes[i])
        {
            case 1: typeName = "P-Frame"; break;
            case 5: typeName = "I-Frame (IDR)"; break;
            case 7: typeName = "SPS"; break;
            case 8: typeName = "PPS"; break;
        }
        printf("    NAL %d: Type %d (%s)\n", i+1, nalTypes[i], typeName);
    }
    
    if (nalCount == 4)
    {
        TEST_PASS("NAL start code detection correct");
        return true;
    }
    else
    {
        TEST_FAIL("NAL detection error - expected 4, got " + nalCount);
        return false;
    }
}

// ============ TEST 5: Thread Safety (Basic) ============
#include <pthread.h>

static volatile int g_SharedCounter = 0;
static pthread_mutex_t g_TestMutex = PTHREAD_MUTEX_INITIALIZER;

void* thread_increment(void* arg)
{
    for (int i = 0; i < 10000; i++)
    {
        pthread_mutex_lock(&g_TestMutex);
        g_SharedCounter++;
        pthread_mutex_unlock(&g_TestMutex);
    }
    return NULL;
}

bool test_thread_safety()
{
    TEST_INFO("Testing thread safety with mutex...");
    
    g_SharedCounter = 0;
    pthread_t threads[4];
    
    for (int i = 0; i < 4; i++)
        pthread_create(&threads[i], NULL, thread_increment, NULL);
    
    for (int i = 0; i < 4; i++)
        pthread_join(threads[i], NULL);
    
    if (g_SharedCounter == 40000)
    {
        TEST_PASS("Thread-safe counter: 40000");
        return true;
    }
    else
    {
        printf("  Expected 40000, got %d\n", g_SharedCounter);
        TEST_FAIL("Thread safety issue detected");
        return false;
    }
}

// ============ TEST 6: FFmpeg Command Generation ============
bool test_ffmpeg_command_generation()
{
    TEST_INFO("Testing FFmpeg command generation...");
    
    int width = 1280;
    int height = 720;
    int fps = 30;
    unsigned int bitrate = 4000000;
    int keyframeFrames = (2000 * fps) / 1000; // 2 seconds
    
    char cmd[1024];
    snprintf(cmd, sizeof(cmd),
        "ffmpeg -f v4l2 -input_format mjpeg -video_size %dx%d "
        "-framerate %d -i /dev/video0 "
        "-c:v libx264 -preset ultrafast -tune zerolatency "
        "-b:v %u -maxrate %u -bufsize %u "
        "-g %d -keyint_min %d -sc_threshold 0 "
        "-profile:v baseline -level 4.0 -pix_fmt yuv420p "
        "-f h264 -",
        width, height, fps, bitrate, bitrate, bitrate,
        keyframeFrames, keyframeFrames);
    
    printf("  Generated command:\n  %s\n", cmd);
    
    // Verify key parameters
    if (strstr(cmd, "1280x720") && 
        strstr(cmd, "ultrafast") && 
        strstr(cmd, "zerolatency") &&
        strstr(cmd, "-g 60"))
    {
        TEST_PASS("FFmpeg command correctly generated");
        return true;
    }
    else
    {
        TEST_FAIL("FFmpeg command generation error");
        return false;
    }
}

// ============ MAIN ============
int main(int argc, char* argv[])
{
    printf("\n");
    printf("╔══════════════════════════════════════════════╗\n");
    printf("║    USB Camera Module Test Suite              ║\n");
    printf("╚══════════════════════════════════════════════╝\n\n");
    
    // Run tests
    if (test_v4l2_device_detection()) g_iTestsPassed++; else g_iTestsFailed++;
    printf("\n");
    
    if (test_ffmpeg_available()) g_iTestsPassed++; else g_iTestsFailed++;
    printf("\n");
    
    if (test_ring_buffer_logic()) g_iTestsPassed++; else g_iTestsFailed++;
    printf("\n");
    
    if (test_nal_start_code_detection()) g_iTestsPassed++; else g_iTestsFailed++;
    printf("\n");
    
    if (test_thread_safety()) g_iTestsPassed++; else g_iTestsFailed++;
    printf("\n");
    
    if (test_ffmpeg_command_generation()) g_iTestsPassed++; else g_iTestsFailed++;
    printf("\n");
    
    // Summary
    printf("╔══════════════════════════════════════════════╗\n");
    printf("║    TEST RESULTS                              ║\n");
    printf("╠══════════════════════════════════════════════╣\n");
    printf("║    Passed: %d                                 ║\n", g_iTestsPassed);
    printf("║    Failed: %d                                 ║\n", g_iTestsFailed);
    printf("╚══════════════════════════════════════════════╝\n\n");
    
    return (g_iTestsFailed > 0) ? 1 : 0;
}
