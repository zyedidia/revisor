# Stub shared libraries for libxul.so dependencies that content processes
# never call. Each stub exports the symbols libxul.so expects, but aborts
# if any function is actually invoked.
#
# Source .c files are committed; this Makefile just compiles them.

CC ?= gcc
CFLAGS := -fPIC -shared

# Map: stub_source -> soname
# The soname must match what libxul.so has in its NEEDED entries.
STUBS := \
	libatk-1.0_stub.c:libatk-1.0.so.0 \
	libcairo-gobject_stub.c:libcairo-gobject.so.2 \
	libcairo_stub.c:libcairo.so.2 \
	libfontconfig_stub.c:libfontconfig.so.1 \
	libfreetype_stub.c:libfreetype.so.6 \
	libgdk-3_stub.c:libgdk-3.so.0 \
	libgdk_pixbuf-2.0_stub.c:libgdk_pixbuf-2.0.so.0 \
	libgio-2.0_stub.c:libgio-2.0.so.0 \
	libglib-2.0_stub.c:libglib-2.0.so.0 \
	libgobject-2.0_stub.c:libgobject-2.0.so.0 \
	libgtk-3_stub.c:libgtk-3.so.0 \
	libpango-1.0_stub.c:libpango-1.0.so.0 \
	libX11_stub.c:libX11.so.6 \
	libX11-xcb_stub.c:libX11-xcb.so.1 \
	libxcb-shm_stub.c:libxcb-shm.so.0 \
	libxcb_stub.c:libxcb.so.1 \
	libXcomposite_stub.c:libXcomposite.so.1 \
	libXdamage_stub.c:libXdamage.so.1 \
	libXext_stub.c:libXext.so.6 \
	libXfixes_stub.c:libXfixes.so.3 \
	libXrandr_stub.c:libXrandr.so.2

SOFILES := $(foreach s,$(STUBS),$(word 2,$(subst :, ,$s)))

.PHONY: all clean

all: $(SOFILES)

# Generate a rule for each stub.
define STUB_RULE
$(word 2,$(subst :, ,$1)): $(word 1,$(subst :, ,$1))
	$$(CC) $$(CFLAGS) -Wl,-soname,$(word 2,$(subst :, ,$1)) -o $$@ $$<
endef

$(foreach s,$(STUBS),$(eval $(call STUB_RULE,$s)))

clean:
	rm -f $(SOFILES)
