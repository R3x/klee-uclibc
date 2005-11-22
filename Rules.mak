# Rules.make for uClibc
#
# Copyright (C) 2000 by Lineo, inc.
# Copyright (C) 2000-2005 Erik Andersen <andersen@uclibc.org>
#
# Licensed under the LGPL v2.1, see the file COPYING.LIB in this tarball.
#

#-----------------------------------------------------------
# This file contains rules which are shared between multiple
# Makefiles.  All normal configuration options live in the 
# file named ".config".  Don't mess with this file unless 
# you know what you are doing.


#-----------------------------------------------------------
# If you are running a cross compiler, you will want to set 
# 'CROSS' to something more interesting ...  Target 
# architecture is determined by asking the CC compiler what 
# arch it compiles things for, so unless your compiler is 
# broken, you should not need to specify TARGET_ARCH.
#
# Most people will set this stuff on the command line, i.e.
#        make CROSS=arm-linux-
# will build uClibc for 'arm'.

ifndef CROSS
CROSS=
endif
CC         = $(CROSS)gcc
AR         = $(CROSS)ar
LD         = $(CROSS)ld
NM         = $(CROSS)nm
STRIPTOOL  = $(CROSS)strip

INSTALL    = install
LN         = ln
RM         = rm -f

STRIP_FLAGS ?= -x -R .note -R .comment

# Select the compiler needed to build binaries for your development system
HOSTCC     = gcc
HOSTCFLAGS = -O2 -Wall


#---------------------------------------------------------
# Nothing beyond this point should ever be touched by mere
# mortals.  Unless you hang out with the gods, you should
# probably leave all this stuff alone.
MAJOR_VERSION := 0
MINOR_VERSION := 9
SUBLEVEL      := 28
VERSION       := $(MAJOR_VERSION).$(MINOR_VERSION).$(SUBLEVEL)
# Ensure consistent sort order, 'gcc -print-search-dirs' behavior, etc.
LC_ALL := C
export MAJOR_VERSION MINOR_VERSION SUBLEVEL VERSION LC_ALL

LIBC := libc
SHARED_MAJORNAME := $(LIBC).so.$(MAJOR_VERSION)
UCLIBC_LDSO := ld-uClibc.so.$(MAJOR_VERSION)
NONSHARED_LIBNAME := uclibc_nonshared.a
libc := $(top_builddir)lib/$(LIBC).so
interp := $(top_builddir)lib/interp.os
ldso := $(top_builddir)lib/$(UCLIBC_LDSO)

#LIBS :=$(interp) -L$(top_builddir)lib -lc
LIBS := $(interp) -L$(top_builddir)lib $(libc)

# Make sure DESTDIR and PREFIX can be used to install
# PREFIX is a uClibcism while DESTDIR is a common GNUism
ifndef PREFIX
PREFIX = $(DESTDIR)
endif

# Pull in the user's uClibc configuration
ifeq ($(filter $(noconfig_targets),$(MAKECMDGOALS)),)
-include $(top_builddir).config
endif

ifndef CROSS
CROSS=$(subst ",, $(strip $(CROSS_COMPILER_PREFIX)))
endif

# A nifty macro to make testing gcc features easier
check_gcc=$(shell \
	if $(CC) $(1) -S -o /dev/null -xc /dev/null > /dev/null 2>&1; \
	then echo "$(1)"; else echo "$(2)"; fi)
check_as=$(shell \
	if $(CC) -Wa,$(1) -Wa,-Z -c -o /dev/null -xassembler /dev/null > /dev/null 2>&1; \
	then echo "-Wa,$(1)"; fi)

# Setup some shortcuts so that silent mode is silent like it should be
ifeq ($(findstring s,$(MAKEFLAGS)),)
export MAKE_IS_SILENT=n
SECHO=@echo
SHELL_SET_X=set -x
else
export MAKE_IS_SILENT=y
SECHO=-@false
SHELL_SET_X=set +x
endif

# Make certain these contain a final "/", but no "//"s.
TARGET_ARCH:=$(shell grep -s ^TARGET_ARCH $(top_builddir)/.config | sed -e 's/^TARGET_ARCH=//' -e 's/"//g')
TARGET_ARCH:=$(strip $(subst ",, $(strip $(TARGET_ARCH))))
RUNTIME_PREFIX:=$(strip $(subst //,/, $(subst ,/, $(subst ",, $(strip $(RUNTIME_PREFIX))))))
DEVEL_PREFIX:=$(strip $(subst //,/, $(subst ,/, $(subst ",, $(strip $(DEVEL_PREFIX))))))
KERNEL_SOURCE:=$(strip $(subst //,/, $(subst ,/, $(subst ",, $(strip $(KERNEL_SOURCE))))))
export RUNTIME_PREFIX DEVEL_PREFIX KERNEL_SOURCE

ARFLAGS:=cr

OPTIMIZATION:=
PICFLAG:=-fPIC
PIEFLAG_NAME:=-fPIE

# Some nice CPU specific optimizations
ifeq ($(TARGET_ARCH),i386)
	OPTIMIZATION+=$(call check_gcc,-mpreferred-stack-boundary=2,)
	OPTIMIZATION+=$(call check_gcc,-falign-jumps=0 -falign-loops=0,-malign-jumps=0 -malign-loops=0)
	CPU_CFLAGS-$(CONFIG_386)+=-march=i386
	CPU_CFLAGS-$(CONFIG_486)+=-march=i486
	CPU_CFLAGS-$(CONFIG_ELAN)+=-march=i486
	CPU_CFLAGS-$(CONFIG_586)+=-march=i586
	CPU_CFLAGS-$(CONFIG_586MMX)+=$(call check_gcc,-march=pentium-mmx,-march=i586)
	CPU_CFLAGS-$(CONFIG_686)+=-march=i686
	CPU_CFLAGS-$(CONFIG_PENTIUMII)+=$(call check_gcc,-march=pentium2,-march=i686)
	CPU_CFLAGS-$(CONFIG_PENTIUMIII)+=$(call check_gcc,-march=pentium3,-march=i686)
	CPU_CFLAGS-$(CONFIG_PENTIUM4)+=$(call check_gcc,-march=pentium4,-march=i686)
	CPU_CFLAGS-$(CONFIG_K6)+=$(call check_gcc,-march=k6,-march=i586)
	CPU_CFLAGS-$(CONFIG_K7)+=$(call check_gcc,-march=athlon,-march=i686) $(call check_gcc,-falign-functions=4,-malign-functions=4)
	CPU_CFLAGS-$(CONFIG_CRUSOE)+=-march=i686 $(call check_gcc,-falign-functions=0,-malign-functions=0)
	CPU_CFLAGS-$(CONFIG_WINCHIPC6)+=$(call check_gcc,-march=winchip-c6,-march=i586)
	CPU_CFLAGS-$(CONFIG_WINCHIP2)+=$(call check_gcc,-march=winchip2,-march=i586)
	CPU_CFLAGS-$(CONFIG_CYRIXIII)+=$(call check_gcc,-march=c3,-march=i486) $(call check_gcc,-falign-functions=0,-malign-functions=0)
	CPU_CFLAGS-$(CONFIG_NEHEMIAH)+=$(call check_gcc,-march=c3-2,-march=i686)
endif

ifeq ($(TARGET_ARCH),sparc)
	CPU_CFLAGS-$(CONFIG_SPARC_V7)+=-mcpu=v7
	CPU_CFLAGS-$(CONFIG_SPARC_V8)+=-mcpu=v8
	CPU_CFLAGS-$(CONFIG_SPARC_V9)+=-mcpu=v9
	CPU_CFLAGS-$(CONFIG_SPARC_V9B)+=$(call check_gcc,-mcpu=v9b,-mcpu=ultrasparc)
endif

ifeq ($(TARGET_ARCH),arm)
	OPTIMIZATION+=-fstrict-aliasing
	CPU_LDFLAGS-$(ARCH_LITTLE_ENDIAN)+=-EL
	CPU_LDFLAGS-$(ARCH_BIG_ENDIAN)+=-EB
	CPU_CFLAGS-$(ARCH_LITTLE_ENDIAN)+=-mlittle-endian
	CPU_CFLAGS-$(ARCH_BIG_ENDIAN)+=-mbig-endian
	CPU_CFLAGS-$(CONFIG_GENERIC_ARM)+=
	CPU_CFLAGS-$(CONFIG_ARM610)+=-mtune=arm610 -march=armv3
	CPU_CFLAGS-$(CONFIG_ARM710)+=-mtune=arm710 -march=armv3
	CPU_CFLAGS-$(CONFIG_ARM720T)+=-mtune=arm7tdmi -march=armv4
	CPU_CFLAGS-$(CONFIG_ARM920T)+=-mtune=arm9tdmi -march=armv4
	CPU_CFLAGS-$(CONFIG_ARM922T)+=-mtune=arm9tdmi -march=armv4
	CPU_CFLAGS-$(CONFIG_ARM926T)+=-mtune=arm9tdmi -march=armv5
	CPU_CFLAGS-$(CONFIG_ARM1136JF_S)+=-mtune=arm1136jf-s -march=armv6
	CPU_CFLAGS-$(CONFIG_ARM_SA110)+=-mtune=strongarm110 -march=armv4
	CPU_CFLAGS-$(CONFIG_ARM_SA1100)+=-mtune=strongarm1100 -march=armv4
	CPU_CFLAGS-$(CONFIG_ARM_XSCALE)+=$(call check_gcc,-mtune=xscale,-mtune=strongarm110)
	CPU_CFLAGS-$(CONFIG_ARM_XSCALE)+=-march=armv4 -Wa,-mcpu=xscale
endif

ifeq ($(TARGET_ARCH),mips)
	CPU_CFLAGS-$(CONFIG_MIPS_ISA_1)+=-mips1
	CPU_CFLAGS-$(CONFIG_MIPS_ISA_2)+=-mips2 -mtune=mips2
	CPU_CFLAGS-$(CONFIG_MIPS_ISA_3)+=-mips3 -mtune=mips3
	CPU_CFLAGS-$(CONFIG_MIPS_ISA_4)+=-mips4 -mtune=mips4
	CPU_CFLAGS-$(CONFIG_MIPS_ISA_MIPS32)+=-mips32 -mtune=mips32
	CPU_CFLAGS-$(CONFIG_MIPS_ISA_MIPS64)+=-mips64 -mtune=mips32
endif

ifeq ($(TARGET_ARCH),sh)
	OPTIMIZATION+=-fstrict-aliasing
	OPTIMIZATION+= $(call check_gcc,-mprefergot,)
	CPU_LDFLAGS-$(ARCH_LITTLE_ENDIAN)+=-EL
	CPU_LDFLAGS-$(ARCH_BIG_ENDIAN)+=-EB
	CPU_CFLAGS-$(ARCH_LITTLE_ENDIAN)+=-ml
	CPU_CFLAGS-$(ARCH_BIG_ENDIAN)+=-mb
	CPU_CFLAGS-$(CONFIG_SH2)+=-m2
	CPU_CFLAGS-$(CONFIG_SH3)+=-m3
ifeq ($(UCLIBC_HAS_FLOATS),y)
	CPU_CFLAGS-$(CONFIG_SH2A)+=-m2a
	CPU_CFLAGS-$(CONFIG_SH4)+=-m4
else
	CPU_CFLAGS-$(CONFIG_SH2A)+=-m2a-nofpu
	CPU_CFLAGS-$(CONFIG_SH4)+=-m4-nofpu
endif
endif

ifeq ($(TARGET_ARCH),sh64)
	OPTIMIZATION+=-fstrict-aliasing
	CPU_LDFLAGS-$(ARCH_LITTLE_ENDIAN):=-EL
	CPU_LDFLAGS-$(ARCH_BIG_ENDIAN):=-EB
	CPU_CFLAGS-$(ARCH_LITTLE_ENDIAN):=-ml
	CPU_CFLAGS-$(ARCH_BIG_ENDIAN):=-mb
	CPU_CFLAGS-$(CONFIG_SH5)+=-m5-32media
endif

ifeq ($(TARGET_ARCH),h8300)
	CPU_LDFLAGS-$(CONFIG_H8300H)+= -ms8300h
	CPU_LDFLAGS-$(CONFIG_H8S)   += -ms8300s
	CPU_CFLAGS-$(CONFIG_H8300H) += -mh -mint32 -fsigned-char
	CPU_CFLAGS-$(CONFIG_H8S)    += -ms -mint32 -fsigned-char
endif

ifeq ($(TARGET_ARCH),cris)
	CPU_LDFLAGS-$(CONFIG_CRIS)+=-mcrislinux
	CPU_CFLAGS-$(CONFIG_CRIS)+=-mlinux
	PICFLAG:=-fpic
	PIEFLAG_NAME:=-fpie
endif

ifeq ($(TARGET_ARCH),powerpc)
# PowerPC can hold 8192 entries in its GOT with -fpic which is more than
# enough. Therefore use -fpic which will reduce code size and generates
# faster code.
	PICFLAG:=-fpic
	PIEFLAG_NAME:=-fpie
endif

ifeq ($(TARGET_ARCH),frv)
	CPU_LDFLAGS-$(CONFIG_FRV)+=-melf32frvfd
	CPU_CFLAGS-$(CONFIG_FRV)+=-mfdpic
	# Using -pie causes the program to have an interpreter, which is
	# forbidden, so we must make do with -shared.  Unfortunately,
	# -shared by itself would get us global function descriptors
	# and calls through PLTs, dynamic resolution of symbols, etc,
	# which would break as well, but -Bsymbolic comes to the rescue.
	export LDPIEFLAG:=-shared -Bsymbolic
	UCLIBC_LDSO=ld.so.1
endif

# Keep the check_gcc from being needlessly executed
ifndef PIEFLAG
ifneq ($(UCLIBC_BUILD_PIE),y)
export PIEFLAG:=
else
export PIEFLAG:=$(call check_gcc,$(PIEFLAG_NAME),$(PICFLAG))
endif
endif
# We need to keep track of both the CC PIE flag (above) as 
# well as the LD PIE flag (below) because we can't rely on 
# gcc passing -pie if we used -fPIE
ifndef LDPIEFLAG
ifneq ($(UCLIBC_BUILD_PIE),y)
export LDPIEFLAG:=
else
export LDPIEFLAG:=$(shell $(LD) --help | grep -q pie && echo "-Wl,-pie")
endif
endif

# Check for AS_NEEDED support in linker script (binutils>=2.16.1 has it)
ifndef ASNEEDED
ifneq ($(UCLIBC_HAS_SSP),y)
export ASNEEDED:=
else
export ASNEEDED:=$(shell (LD_TMP=$(mktemp LD_XXXXXX) ; echo "GROUP ( AS_NEEDED ( /usr/lib/libc.so ) )" > $LD_TMP && if $(LD) -T $LD_TMP -o /dev/null > /dev/null 2>&1; then echo "AS_NEEDED ( $(UCLIBC_LDSO) )"; else echo "$(UCLIBC_LDSO)"; fi; rm -f $LD_TMP ) )
endif
endif

# Use '-Os' optimization if available, else use -O2, allow Config to override
OPTIMIZATION+=$(call check_gcc,-Os,-O2)
# Use the gcc 3.4 -funit-at-a-time optimization when available
OPTIMIZATION+=$(call check_gcc,-funit-at-a-time,)

# Add a bunch of extra pedantic annoyingly strict checks
XWARNINGS=$(subst ",, $(strip $(WARNINGS))) -Wstrict-prototypes -Wno-trigraphs -fno-strict-aliasing
XARCH_CFLAGS=$(subst ",, $(strip $(ARCH_CFLAGS)))
CPU_CFLAGS=$(subst ",, $(strip $(CPU_CFLAGS-y)))

LDADD_LIBFLOAT=
ifeq ($(UCLIBC_HAS_SOFT_FLOAT),y)
# Add -msoft-float to the CPU_FLAGS since ldso and libdl ignore CFLAGS.
# If -msoft-float isn't supported, we want an error anyway.
# Hmm... might need to revisit this for arm since it has 2 different
# soft float encodings.
    CPU_CFLAGS += -msoft-float
ifeq ($(TARGET_ARCH),arm)
# No longer needed with current toolchains, but leave it here for now.
# If anyone is actually still using gcc 2.95 (say), they can uncomment it.
#    LDADD_LIBFLOAT=-lfloat
endif
endif

SSP_DISABLE_FLAGS?=$(call check_gcc,-fno-stack-protector,)
ifeq ($(UCLIBC_BUILD_SSP),y)
SSP_CFLAGS:=$(call check_gcc,-fno-stack-protector-all,)
SSP_CFLAGS+=$(call check_gcc,-fstack-protector,)
SSP_ALL_CFLAGS?=$(call check_gcc,-fstack-protector-all,)
else
SSP_CFLAGS:=$(SSP_DISABLE_FLAGS)
endif

# Some nice CFLAGS to work with
CFLAGS:=$(XWARNINGS) $(CPU_CFLAGS) $(SSP_CFLAGS) \
	-fno-builtin -nostdinc -D_LIBC -I$(top_builddir)include -I.

LDFLAGS_NOSTRIP:=$(CPU_LDFLAGS-y) -shared --warn-common --warn-once -z combreloc

ifeq ($(UCLIBC_BUILD_RELRO),y)
LDFLAGS_NOSTRIP+=-z relro
endif

ifeq ($(UCLIBC_BUILD_NOW),y)
LDFLAGS_NOSTRIP+=-z now
endif

LDFLAGS:=$(LDFLAGS_NOSTRIP) -z defs
ifeq ($(DODEBUG),y)
    #CFLAGS += -g3
    CFLAGS += -O0 -g3
    STRIPTOOL:= true -Since_we_are_debugging
else
    CFLAGS += $(OPTIMIZATION) $(XARCH_CFLAGS)
    LDFLAGS += -s
endif

ifeq ($(DOMULTI),y)
# we try to compile all sources at once into an object (IMA), but
# gcc-3.3.x does not support it
# gcc-3.4.x supports it, but does not need and support --combine. though fails on many sources
# gcc-4.0.x supports it, supports the --combine flag, but does not need it
# gcc-4.1(200506xx) supports it, but needs the --combine flag, else libs are useless
GCC_VER?=$(shell $(CC) -dumpversion | cut -d . -f 1)
ifeq ($(GCC_VER),3)
DOMULTI:=n
else
CFLAGS+=$(call check_gcc,--combine,)
endif
else
DOMULTI:=n
endif

ifeq ($(UCLIBC_HAS_THREADS),y)
ifeq ($(UCLIBC_HAS_THREADS_NATIVE),y)
	PTNAME := nptl
else
ifeq ($(LINUXTHREADS_OLD),y)
	PTNAME := linuxthreads.old
else
	PTNAME := linuxthreads
endif
endif
PTDIR := $(top_builddir)libpthread/$(PTNAME)
# set up system dependencies include dirs (NOTE: order matters!)
ifeq ($(UCLIBC_HAS_THREADS_NATIVE),y)
PTINC := \
	-I$(PTDIR)/compat					\
	-I$(PTDIR)/sysdeps/unix/sysv/linux/$(TARGET_ARCH)	\
	-I$(PTDIR)/sysdeps/$(TARGET_ARCH)			\
	-I$(PTDIR)/sysdeps/unix/sysv/linux			\
	-I$(PTDIR)/sysdeps/pthread				\
	-I$(PTDIR)/sysdeps/pthread/bits				\
	-I$(PTDIR)/sysdeps/generic				\
	-Ildso/include						\
	-include $(PTDIR)/compat/libc-symbols.h
#
# Test for TLS if NPTL support was selected.
#
GCC_HAS_TLS=$(shell \
	echo "extern __thread int foo;" | $(CC) -o /dev/null -S -xc - 2>&1)
ifneq ($(GCC_HAS_TLS),)
gcc_tls_test_fail:
	@echo "####";
	@echo "#### Your compiler does not support TLS and you are trying to build uClibc";
	@echo "#### with NPTL support. Upgrade your binutils and gcc to versions which";
	@echo "#### support TLS for your architecture. Do not contact uClibc maintainers";
	@echo "#### about this problem.";
	@echo "####";
	@echo "#### Exiting...";
	@echo "####";
	@exit 1;
endif
else
PTINC := \
	-I$(PTDIR)/sysdeps/$(TARGET_ARCH) \
	-I$(PTDIR)/sysdeps/pthread \
	-I$(top_builddir)libpthread
endif
CFLAGS+=$(PTINC)
else
	PTNAME := 
	PTINC  := 
endif

# Sigh, some stupid versions of gcc can't seem to cope with '-iwithprefix include'
#CFLAGS+=-iwithprefix include
CFLAGS+=-isystem $(shell $(CC) -print-file-name=include)

ifneq ($(DOASSERTS),y)
CFLAGS+=-DNDEBUG
endif

# moved from ldso/{ldso,libdl}
# BEWARE!!! At least mips* will die if -O0 is used!!!
ifeq ($(TARGET_ARCH),mips)
CFLAGS:=$(CFLAGS:-O0=-O1)
endif

# Keep the check_as from being needlessly executed
ifndef ASFLAGS_NOEXEC
ifeq ($(UCLIBC_BUILD_NOEXECSTACK),y)
export ASFLAGS_NOEXEC := $(call check_as,--noexecstack)
else
export ASFLAGS_NOEXEC :=
endif
endif
ASFLAGS = $(ASFLAGS_NOEXEC)

LIBGCC_CFLAGS ?= $(CFLAGS) $(CPU_CFLAGS-y)
LIBGCC:=$(shell $(CC) $(LIBGCC_CFLAGS) -print-libgcc-file-name)
LIBGCC_DIR:=$(dir $(LIBGCC))

# moved from libpthread/linuxthreads
ifeq ($(UCLIBC_CTOR_DTOR),y)
SHARED_START_FILES:=$(top_builddir)lib/crti.o $(LIBGCC_DIR)crtbeginS.o
SHARED_END_FILES:=$(LIBGCC_DIR)crtendS.o $(top_builddir)lib/crtn.o
endif

########################################
#
# uClinux shared lib support
#

ifeq ($(CONFIG_BINFMT_SHARED_FLAT),y)
  # For the shared version of this, we specify no stack and its library ID
  FLTFLAGS += -s 0
  LIBID=1
  export LIBID FLTFLAGS
  SHARED_TARGET = lib/libc
endif
