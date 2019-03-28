################################################################################
#
# icudata
#
################################################################################

ICU_VERSION = 60.2

ICUDATA_SOURCE = icu4c-$(subst .,_,$(ICU_VERSION))-data.zip
ICUDATA_SITE = http://download.icu-project.org/files/icu4c/$(ICU_VERSION)
ICUDATA_LICENSE = ICU License
ICUDATA_LICENSE_FILES = license.html
ICUDATA_EXTRACT_CMDS += zip

define ICUDATA_EXTRACT
    rm -rf $(@D)/source/data
    unzip $(DL_DIR)/$(ICUDATA_SOURCE) -d $(@D)/source
    dos2unix $(@D)/source/data/Makefile.in
endef

$(eval $(generic-package))
$(eval $(host-generic-package))
