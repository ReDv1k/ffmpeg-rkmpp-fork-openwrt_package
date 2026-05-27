#
# Copyright (C) 2022 jjm2473 <jjm2473@gmail.com>
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=ffmpeg-rkmpp
PKG_VERSION:=1.0
PKG_RELEASE:=1

PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION).tar.gz
PKG_SOURCE_PROTO:=git
PKG_SOURCE_VERSION:=0983084625e2ad38f768411b332d7975fceafd1e
PKG_SOURCE_URL_FILE:=$(PKG_SOURCE_VERSION).tar.gz
PKG_SOURCE_URL:=https://github.com/nyanmisaka/ffmpeg-rockchip.git
PKG_MIRROR_HASH:=e2ceefc5528cbb35446418e55c86c9afd17064b32999fea196a4f75fc2fd5196

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)

FFMPEG_PATENTED_DECODERS:= \
	atrac3 \
	hevc \
	vc1 \

FFMPEG_PATENTED_MUXERS:= \
	hevc \
	vc1 \

FFMPEG_PATENTED_DEMUXERS:=$(FFMPEG_PATENTED_MUXERS)

FFMPEG_PATENTED_PARSERS:= \
	hevc \
	vc1 \

FFMPEG_BLACKLIST_ENCODERS:= \
	svq1 \

include $(INCLUDE_DIR)/package.mk

TAR_OPTIONS:=--strip-components 1 $(TAR_OPTIONS)
TAR_CMD=$(HOST_TAR) -C $(1) $(TAR_OPTIONS)

define Package/ffmpeg-rkmpp/Default
 TITLE:=FFmpeg for rockchip SoC
 URL:=https://github.com/nyanmisaka
 DEPENDS+=@aarch64 @!ALL +libpthread
endef

define Package/ffmpeg-rkmpp/Default/description
 FFmpeg is a a software package that can record, convert and stream digital
 audio and video in numerous formats.

 FFmpeg licensing / patent issues are complex. It is the reponsibility of the
 user to understand any requirements in this regard with its usage. See:
 https://ffmpeg.org/legal.html for further information.

 This is a rockchip mpp variant.
endef

define Package/ffmpeg-rkmpp
$(call Package/ffmpeg/Default)
 SECTION:=multimedia
 CATEGORY:=Multimedia
 TITLE+= program
 DEPENDS+= +libffmpeg-rkmpp
 PROVIDES:= ffmpeg
endef

define Package/ffmpeg-rkmpp/description
$(call Package/ffmpeg-rkmpp/Default/description)
 .
 This package contains the FFmpeg command line tool.
endef

define Package/ffprobe-rkmpp
$(call Package/ffmpeg-rkmpp/Default)
 SECTION:=multimedia
 CATEGORY:=Multimedia
 TITLE+= CLI media identifier
 DEPENDS+= +libffmpeg-rkmpp
 PROVIDES:= ffprobe
endef

define Package/ffprobe-rkmpp/description
$(call Package/ffmpeg-rkmpp/Default/description)
 .
 This package contains the FFprobe command line tool.
endef

define Package/libffmpeg-rkmpp
$(call Package/ffmpeg-rkmpp/Default)
 SECTION:=libs
 CATEGORY:=Libraries
 TITLE+= libraries
 DEPENDS+= +zlib +libbz2
 PROVIDES:= libffmpeg libavcodec.so.59 libavformat.so.59 libavutil.so.57 libswresample.so.4
 TITLE+= (full)
 DEPENDS+= +AUDIO_SUPPORT:alsa-lib +libgnutls +libopus \
    +SOFT_FLOAT:shine \
    +!SOFT_FLOAT:lame-lib \
    +libx264 \
    +rkrga \
    +libv4l \
	+mpp \
	+libdrm \
    +fdk-aac 
endef

define Package/libffmpeg-rkmpp/description
$(call Package/ffmpeg-rkmpp/Default/description)
 .
 This package contains full-featured FFmpeg shared libraries.
endef

REAL_CPU_TYPE:=$(firstword $(subst +, ,$(CONFIG_CPU_TYPE)))

REAL_CPU_TYPE:=$(subst octeonplus,octeon+,$(REAL_CPU_TYPE))

FFMPEG_CONFIGURE:= \
	CFLAGS="$(TARGET_CFLAGS) $(TARGET_CPPFLAGS) $(FPIC)" \
	LDFLAGS="$(TARGET_LDFLAGS)" \
	./configure \
	--enable-cross-compile \
	--cross-prefix="$(TARGET_CROSS)" \
	--arch="$(ARCH)" \
	$(if $(REAL_CPU_TYPE),--cpu=$(call qstrip,$(REAL_CPU_TYPE)),) \
	--target-os=linux \
	--prefix="/usr" \
	--pkg-config="pkg-config" \
	--enable-shared \
	--enable-static \
	--enable-pthreads \
	--enable-zlib \
	--disable-doc \
	--disable-debug \
	\
	--disable-lzma \
	--disable-vaapi \
	--disable-vdpau \
	#--disable-v4l2-m2m 

ifeq ($(CONFIG_SOFT_FLOAT),y)
FFMPEG_CONFIGURE+= \
	--disable-altivec \
	--disable-vsx \
	--disable-power8 \
	--disable-armv5te \
	--disable-armv6 \
	--disable-armv6t2 \
	--disable-fast-unaligned \
	--disable-runtime-cpudetect
else ifneq ($(findstring arm,$(CONFIG_ARCH))$(findstring aarch64,$(CONFIG_ARCH)),)
FFMPEG_CONFIGURE+= \
	--disable-runtime-cpudetect
# XXX: GitHub issue 3320 ppc cpu with fpu but no altivec (WNDR4700)
else ifneq ($(findstring powerpc,$(CONFIG_ARCH)),)
FFMPEG_CONFIGURE+= \
	--disable-altivec
endif

# selectively disable optimizations according to arch/cpu type
ifneq ($(findstring arm,$(CONFIG_ARCH)),)
	FFMPEG_CONFIGURE+= --enable-lto

	ifneq ($(findstring vfp,$(CONFIG_CPU_TYPE)),)
		FFMPEG_CONFIGURE+= --enable-vfp
	else
		FFMPEG_CONFIGURE+= --disable-vfp
	endif
	ifneq ($(findstring neon,$(CONFIG_CPU_TYPE)),)
		FFMPEG_CONFIGURE+= \
			--enable-neon \
			--enable-vfp
	else
		FFMPEG_CONFIGURE+= --disable-neon
	endif
endif

ifneq ($(findstring aarch64,$(CONFIG_ARCH)),)
	FFMPEG_CONFIGURE+= \
		--enable-lto \
		--enable-neon \
		--enable-vfp
endif

FFMPEG_DISABLE= \
$(foreach c, $(2), \
	--disable-$(1)="$(c)" \
)

FFMPEG_CONFIGURE+= \
	--enable-gnutls \
	$(call FFMPEG_DISABLE,encoder,$(FFMPEG_BLACKLIST_ENCODERS)) \
	$(if $(CONFIG_BUILD_PATENTED),, \
		$(call FFMPEG_DISABLE,decoder,$(FFMPEG_PATENTED_DECODERS)) \
		$(call FFMPEG_DISABLE,muxer,$(FFMPEG_PATENTED_MUXERS)) \
		$(call FFMPEG_DISABLE,demuxer,$(FFMPEG_PATENTED_DEMUXERS)) \
		$(call FFMPEG_DISABLE,parser,$(FFMPEG_PATENTED_PARSERS))) \
	$(if $(CONFIG_PACKAGE_libopus),--enable-libopus)
ifeq ($(CONFIG_SOFT_FLOAT),y)
FFMPEG_CONFIGURE+= \
	--enable-small \
	\
	$(if $(CONFIG_PACKAGE_shine),--enable-libshine)
else
FFMPEG_CONFIGURE+= --enable-hardcoded-tables
FFMPEG_CONFIGURE+= $(if $(CONFIG_PACKAGE_lame-lib),--enable-libmp3lame)
endif

FFMPEG_CONFIGURE+= \
--enable-indev=v4l2 \
--enable-libv4l2 \
--enable-gpl \
--enable-libx264 \
--enable-version3 \
--enable-nonfree \
--enable-libdrm \
--enable-rkmpp \
--enable-rkrga \
--enable-network \
--enable-protocol=rtsp \
--enable-protocol=tcp \
--enable-protocol=udp \
--enable-muxer=rtsp \
--enable-demuxer=rtsp \

FFMPEG_CONFIGURE+= $(if $(CONFIG_PACKAGE_fdk-aac),--enable-libfdk-aac)

ifeq ($(CONFIG_AUDIO_SUPPORT),)
FFMPEG_CONFIGURE+= \
	--disable-alsa
endif

ifneq ($(CONFIG_TARGET_x86),)
  TARGET_CFLAGS+= -fomit-frame-pointer
endif

define Build/Configure
	( cd $(PKG_BUILD_DIR); $(FFMPEG_CONFIGURE) )
endef

define Build/Compile
	$(MAKE) -C $(PKG_BUILD_DIR) \
		DESTDIR="$(PKG_INSTALL_DIR)" \
		all install
endef

define Build/InstallDev
	$(INSTALL_DIR) $(1)/usr/include
	$(INSTALL_DIR) $(1)/usr/lib
	$(INSTALL_DIR) $(1)/usr/lib/pkgconfig
	$(CP) $(PKG_INSTALL_DIR)/usr/include/lib{avcodec,avdevice,avfilter,avformat,avutil,swresample,swscale} $(1)/usr/include/
	$(CP) $(PKG_INSTALL_DIR)/usr/lib/lib{avcodec,avdevice,avfilter,avformat,avutil,swresample,swscale}.{a,so*} $(1)/usr/lib/
	$(CP) $(PKG_INSTALL_DIR)/usr/lib/pkgconfig/lib{avcodec,avdevice,avfilter,avformat,avutil,swresample,swscale}.pc $(1)/usr/lib/pkgconfig/
	$(CP) $(PKG_INSTALL_DIR)/usr/include/libpostproc $(1)/usr/include/
	$(CP) $(PKG_INSTALL_DIR)/usr/lib/libpostproc.{a,so*} $(1)/usr/lib/
	$(CP) $(PKG_INSTALL_DIR)/usr/lib/pkgconfig/libpostproc.pc $(1)/usr/lib/pkgconfig/
endef

define Package/ffmpeg-rkmpp/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(CP) $(PKG_INSTALL_DIR)/usr/bin/ffmpeg $(1)/usr/bin/
endef

define Package/ffprobe-rkmpp/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(CP) $(PKG_INSTALL_DIR)/usr/bin/ffprobe $(1)/usr/bin/
endef

define Package/libffmpeg-rkmpp/install
	$(INSTALL_DIR) $(1)/usr/lib
	$(CP) $(PKG_INSTALL_DIR)/usr/lib/lib{avcodec,avdevice,avfilter,avformat,avutil,swresample,swscale}.so.* $(1)/usr/lib/
	$(CP) $(PKG_INSTALL_DIR)/usr/lib/libpostproc.so.* $(1)/usr/lib/
endef

$(eval $(call BuildPackage,ffmpeg-rkmpp))
$(eval $(call BuildPackage,ffprobe-rkmpp))
$(eval $(call BuildPackage,libffmpeg-rkmpp))
