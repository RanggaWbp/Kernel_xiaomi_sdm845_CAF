# needed for trace events: mdss_pll_trace.h re-includes itself through
# <trace/define_trace.h> as a quoted include, which -nostdinc can only
# resolve via an explicit -I for this directory. Same line as
# drivers/android/Makefile and drivers/video/fbdev/msm/Makefile.
ccflags-y += -I$(src)

obj-$(CONFIG_QCOM_MDSS_PLL) += mdss-pll-util.o
obj-$(CONFIG_QCOM_MDSS_PLL) += mdss-pll.o
obj-$(CONFIG_QCOM_MDSS_PLL) += mdss-dsi-pll-10nm.o
obj-$(CONFIG_QCOM_MDSS_PLL) += mdss-dp-pll-10nm.o
obj-$(CONFIG_QCOM_MDSS_PLL) += mdss-dp-pll-10nm-util.o

