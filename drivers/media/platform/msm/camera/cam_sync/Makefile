ccflags-y += -Idrivers/media/platform/msm/camera/cam_utils

obj-$(CONFIG_SPECTRA_CAMERA) += cam_sync.o cam_sync_util.o
# headers included by neighbouring directories resolve only via -I for this directory
ccflags-y += -I$(src)
