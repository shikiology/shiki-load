R8168_VERSION = 0e477c861eabae29cb91cc0bda68913ae4778797
R8168_SITE = R8125_SITE = $(call github,shikiology,r8168,$(R8168_VERSION))
R8168_LICENSE = GPL-2.0

$(eval $(kernel-module))
$(eval $(generic-package))
