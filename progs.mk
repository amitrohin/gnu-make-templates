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
# cc  -c -MT obj/p1a.c.o  -MMD -MP -MF obj/p1a.c.deps  p1a.c  -o obj/p1a.c.o
# c++ -c -MT obj/p1b.cc.o -MMD -MP -MF obj/p1b.cc.deps p1b.cc -o obj/p1b.cc.o
# c++ obj/p1a.c.o obj/p1b.cc.o -o p1
# cc -c -MT obj/p2.c.o -MMD -MP -MF obj/p2.c.deps p2.c -o obj/p2.c.o
# cc obj/p2.c.o  -o p2
#
# We can define parameters that will be chosen in order of priority
# (leftmost has the highest priority):
# CFLAGS.$s     CFLAGS.$p       CFLAGS
# CXXFLAGS.$s   CXXFLAGS.$p     CXXFLAGS
# CPPFLAGS.$s   CPPFLAGS.$p     CPPFLAGS
#               LDFLAGS.$p      LDFLAGS
#               LDLIBS.$p       LDLIBS
# CC.$s         CC.$p           CC
# CXX.$s        CXX.$p          CXX
#               LD.$p           CC or CXX
# where p is the program name, s is the source file name.
#
# PROGS = p1 p2
# SRCS.p1 = p1a.c p1b.cc
# CFLAGS.p1a.c = $(CFLAGS.p1) -O6
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
		$(#info SRCS.$p = $(value SRCS.$p))

		$(eval OBJS.$p += $(addprefix $(OBJDIR)/,$(addsuffix .o,$(SRCS.$p))))
		$(#info OBJS.$p = $(value OBJS.$p))
		$(eval OBJS += $(OBJS.$p))

		$(eval DEPS.$p += $(OBJS.$p:%.o=%$(DEPSUFFIX)))
		$(#info DEPS.$p = $(value DEPS.$p))
		$(eval DEPS += $(DEPS.$p))

		$(if $(CFLAGS.$p),,$(eval CFLAGS.$p = $$(CFLAGS)))
		$(if $(CXXFLAGS.$p),,$(eval CXXFLAGS.$p = $$(CXXFLAGS)))
		$(if $(CPPFLAGS.$p),,$(eval CPPFLAGS.$p = $$(CPPFLAGS)))
                $(if $(LDFLAGS.$p),,$(eval LDFLAGS.$p = $$(LDFLAGS)))
                $(if $(LDLIBS.$p),,$(eval LDLIBS.$p = $$(LDLIBS)))

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
			$(if $(CFLAGS.$s),,$(eval CFLAGS.$s = $$(CFLAGS.$p)))
			$(if $(CXXFLAGS.$s),,$(eval CXXFLAGS.$s = $$(CXXFLAGS.$p)))
			$(if $(CPPFLAGS.$s),,$(eval CPPFLAGS.$s = $$(CPPFLAGS.$p)))
			$(if $(filter %.c,$s),
				$(if $(CC.$s),,$(eval CC.$s = $(CC.$p)))
				$(eval COMPILE.$s = $$(CC.$s) -c $$(CFLAGS.$s))
			,
				$(if $(CXX.$s),,$(eval CXX.$s = $(CXX.$p)))
				$(eval COMPILE.$s = $$(CXX.$s) -c $$(CXXFLAGS.$s))
			)
			$(eval COMPILE.$s += $$(CPPFLAGS.$s) $$(DEPFLAGS))
			$(#info COMPILE.$s = $(value COMPILE.$s))
			$(eval $(OBJDIR)/$s.o: $s | $(OBJDIR); $$(COMPILE.$s) $$< -o $$@)
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
