#pragma once
#include "../base/base.h"
#include "../base/models.h"

// USB Camera States
typedef enum {
    USB_CAMERA_STATE_STOPPED = 0,
    USB_CAMERA_STATE_STARTING,
    USB_CAMERA_STATE_RUNNING,
    USB_CAMERA_STATE_ERROR,
    USB_CAMERA_STATE_DEVICE_LOST
} usb_camera_state_t;

// Buffer sizes
#define USB_CAMERA_BUFFER_SIZE (256 * 1024)       // 256KB per buffer
#define USB_CAMERA_RING_BUFFER_COUNT 8            // Ring buffer slots
#define USB_CAMERA_MAX_NAL_SIZE (128 * 1024)      // Max single NAL unit

// Default video settings
#define USB_CAMERA_DEFAULT_WIDTH 1280
#define USB_CAMERA_DEFAULT_HEIGHT 720
#define USB_CAMERA_DEFAULT_FPS 30
#define USB_CAMERA_DEFAULT_DEVICE "/dev/video0"

// ============ PUBLIC FUNCTIONS ============

// Lifecycle
u32 video_source_usb_start_program(u32 uOverwriteInitialBitrate, 
                                    int iOverwriteInitialKFMs, 
                                    int iOverwriteInitialQPDelta, 
                                    int* pInitialKFSet);
void video_source_usb_stop_program();
u32 video_source_usb_get_program_start_time();

// Data reading
u8* video_source_usb_read(int* piReadSize, bool bAsync, u32* puOutTimeDataAvailable);
void video_source_usb_clear_input_buffers();

// NAL unit info
bool video_source_usb_last_read_is_single_nal();
bool video_source_usb_last_read_is_start_nal();
bool video_source_usb_last_read_is_end_nal();
u32 video_source_usb_get_last_nal_type();

// Parameters
void video_source_usb_apply_all_parameters();

// Audio (thermal cameras typically have no audio)
int video_source_usb_get_audio_data(u8* pOutputBuffer, int iMaxToRead);
void video_source_usb_clear_audio_buffers();

// Health and status
bool video_source_usb_periodic_health_checks();
bool video_source_usb_is_available();
usb_camera_state_t video_source_usb_get_state();
