# https://make.mad-scientist.net/papers/advanced-auto-dependency-generation
#
# Template for building multiple programs located in the current directory.
# This is typically needed for educational or test programs that may
# consist of one or two files. We can list the names of the resulting
# programs in the variable PROGS.
#
# PROGS = prog1 prog2
#
# As a result, make will look for prog1.c or prog1.cc and try to
# build prog1 without any additional parameters:
#
#       cc -c prog1.c -o obj/prog1.o
#       cc obj/prog1.o -o prog1
#
# Similar actions will be performed for the second program.
# If the source program has a .cc extension, the compiler will be $(CXX).
#
#       c++ -c prog2.cc -o obj/prog2.o
#       c++ obj/prog2.o -o prog2
#
# If a program consists of multiple files, they must be listed in
# SRCS.<program name>:
#
# PROGS = p1 p2
# SRCS.p1 = p1a.c p1b.cc
#
# $ gmake -n
# cc  -c -MT obj/p1.p1a.c.o  -MMD -MP -MF obj/p1.p1a.c.deps  p1a.c  -o obj/p1.p1a.c.o
# c++ -c -MT obj/p1.p1b.cc.o -MMD -MP -MF obj/p1.p1b.cc.deps p1b.cc -o obj/p1.p1b.cc.o
# c++ obj/p1.p1a.c.o obj/p1.p1b.cc.o -o p1
# cc -c -MT obj/p1.p2.c.o -MMD -MP -MF obj/p2.p2.c.deps p2.c -o obj/p2.p2.c.o
# cc obj/p2.p2.c.o  -o p2
#
# We can define parameters that will be chosen in order of priority
# (leftmost has the highest priority):
# CFLAGS.$p.$s     CFLAGS.$p       CFLAGS
# CXXFLAGS.$p.$s   CXXFLAGS.$p     CXXFLAGS
# CPPFLAGS.$p.$s   CPPFLAGS.$p     CPPFLAGS
#                  LDFLAGS.$p      LDFLAGS
#                  LDLIBS.$p       LDLIBS
# CC.$p.$s         CC.$p           CC
# CXX.$p.$s        CXX.$p          CXX
#                  LD.$p           CC or CXX
# where p is the program name, s is the source file name.
#
# PROGS = p1 p2
# SRCS = common.c
# SRCS.p1 = p1a.c p1b.cc
# CFLAGS.p1.p1a.c = $(CFLAGS.p1) -O6
# LDLIBS.p1 = -lm
#
# $ gmake -n
# cc  -c -O6 -MT obj/p1a.c.o  -MMD -MP -MF obj/p1a.c.deps  p1a.c  -o obj/p1a.c.o
# c++ -c     -MT obj/p1b.cc.o -MMD -MP -MF obj/p1b.cc.deps p1b.cc -o obj/p1b.cc.o
# c++ obj/p1a.c.o obj/p1b.cc.o -lm -o p1
# cc -c -MT obj/p2.c.o -MMD -MP -MF obj/p2.c.deps p2.c -o obj/p2.c.o
# cc obj/p2.c.o -o p2
#
# All build artifacts will be placed in obj/, and the compiled
# programs in the current directory.

.SUFFIXES:

PROGS :=

#CFLAGS ?= -g -O0 -pipe
#CXXFLAGS ?= $(CFLAGS)
#CPPFLAGS ?= -I/usr/local/include
#LDFLAGS ?= -L/usr/local/lib
#LDLIBS ?= -lpthread -lm

OBJDIR ?= obj

# -MT $@
#    Set the name of the target in the generated dependency file.
#
# -MMD
#    Generate dependency information as a side-effect of compilation, not
#    instead of compilation. This version omits system headers from the
#    generated dependencies: if you prefer to preserve system headers as
#    prerequisites, use -MD.
#
# -MP
#    Adds a target for each prerequisite in the list, to avoid errors when
#    deleting files.
#
# -MF $(DEPDIR)/$*.d
#    Write the generated dependency file $(DEPDIR)/$*.d.
#
DEPSUFFIX := .deps
DEPFLAGS = -MT $@ -MMD -MP -MF $(basename $@)$(DEPSUFFIX)

DESTDIR ?= /usr/local
BINDIR ?= $(DESTDIR)/bin

INSTALL ?= install

define make =
$(strip
	$(eval .PHONY: all)
	$(eval all: $(PROGS))

	$(foreach p,$(PROGS),
		$(if $(SRCS.$p),,$(eval SRCS.$p := $(wildcard $p.c $p.cc)))
		$(eval SRCS.$p += $(SRCS))
		$(#info SRCS.$p = $(value SRCS.$p))

		$(eval OBJS.$p += $(addprefix $(OBJDIR)/$p.,$(addsuffix .o,$(SRCS.$p))))
		$(#info OBJS.$p = $(value OBJS.$p))
		$(eval OBJS += $(OBJS.$p))

		$(eval DEPS.$p += $(OBJS.$p:%.o=%$(DEPSUFFIX)))
		$(#info DEPS.$p = $(value DEPS.$p))
		$(eval DEPS += $(DEPS.$p))

		$(eval CFLAGS.$p = $(CFLAGS) $(CFLAGS.$p))
		$(eval CXXFLAGS.$p = $(CXXFLAGS) $(CXXFLAGS.$p))
		$(eval CPPFLAGS.$p = $(CPPFLAGS) $(CPPFLAGS.$p))
		$(eval LDFLAGS.$p = $(LDFLAGS) $(LDFLAGS.$p))
		$(eval LDLIBS.$p = $(LDLIBS) $(LDLIBS.$p))

		$(if $(CC.$p),,$(eval CC.$p = $(CC)))
		$(#info CC.$p = $(CC.$p))

		$(if $(CXX.$p),,$(eval CXX.$p = $(CXX)))
		$(#info CXX.$p = $(CXX.$p))

		$(if $(LD.$p),,
			$(if $(filter %.cc,$(SRCS.$p)),
				$(eval LD.$p = $$(CXX.$p))
			,
				$(eval LD.$p = $$(CC.$p))
			)
		)
		$(#info LD.$p = $(LD.$p))

		$(foreach s,$(SRCS.$p),
			$(eval CFLAGS.$p.$s = $(CFLAGS.$p) $(CFLAGS.$p.$s))
			$(eval CXXFLAGS.$p.$s = $(CXXFLAGS.$p) $(CXXFLAGS.$p.$s))
			$(eval CPPFLAGS.$p.$s = $(CPPFLAGS.$p) $(CPPFLAGS.$p.$s))
			$(if $(filter %.c,$s),
                                $(if $(CC.$p.$s),,$(eval CC.$p.$s = $(CC.$p)))
                                $(eval COMPILE.$p.$s = $$(CC.$p.$s) -c $$(CFLAGS.$p.$s))
			,
                                $(if $(CXX.$p.$s),,$(eval CXX.$p.$s = $(CXX.$p)))
                                $(eval COMPILE.$p.$s = $$(CXX.$p.$s) -c $$(CXXFLAGS.$p.$s))
			)
                        $(eval COMPILE.$p.$s += $$(CPPFLAGS.$p.$s) $$(DEPFLAGS))
                        $(#info COMPILE.$p.$s = $(value COMPILE.$p.$s))
                        $(eval $(OBJDIR)/$p.$s.o: $s | $(OBJDIR); $$(COMPILE.$p.$s) $$< -o $$@)

		)
		$(eval $p: $(OBJS.$p); $$(LD.$p) $$(LDFLAGS.$p) $$^ $$(LDLIBS.$p) -o $$@)

		$(eval OBJS := $(sort $(OBJS)))
		$(eval DEPS := $(sort $(DEPS)))
		$(#Include the dependency files that exist. Use wildcard to avoid failing on non-existent files.)
		$(eval include $(wildcard $(DEPS)))

	)
	$(eval $(OBJDIR):; mkdir -p $$@)

	$(eval .PHONY: clean)
	$(eval clean:; @-for f in $$(OBJS) $$(DEPS) $$(PROGS); do unlink $$$$f 2>/dev/null && echo "unlink $$$$f"; done)
)
endef
$(call make)

.PHONY: install
#install: $(PROG); $(INSTALL) -m 755 $(PROG) $(BINDIR)/
