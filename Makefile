# 1. Compiler and Toolchain Settings
CXX      ?= g++
CC       ?= gcc
RM       := rm -rf
MKDIR    := mkdir -p

# 2. Project Target Name
TARGET   := main

# 3. Directory Layout
SRCDIR   := src
INCDIR   := include
BUILDDIR := build
BINDIR   := bin

TESTDIR  := tests
TESTBINDIR := $(BINDIR)/tests

# 4. Compiler & Linker Flags
# -MMD -MP generates tracking files (.d) for header changes automatically
CFLAGS   := -Wall -Wextra -O2 -I$(INCDIR)
CXXFLAGS := -Wall -Wextra -O2 -std=c++17 -I$(INCDIR)
LDFLAGS  := 
LDLIBS   := -lpthread

# 5. Source and Object File Discovery
# Automatically finds all .c and .cpp files in SRCDIR
SRCS_C   := $(shell find $(SRCDIR) -type f -name "*.c" 2>/dev/null)
SRCS_CXX := $(shell find $(SRCDIR) -type f -name "*.cpp" 2>/dev/null)

# Discover test source files
TEST_SRCS_C   := $(shell find $(TESTDIR) -type f -name "*.c" 2>/dev/null)
TEST_SRCS_CXX := $(shell find $(TESTDIR) -type f -name "*.cpp" 2>/dev/null)

# Each test source gets its own executable
TEST_BINS := $(patsubst $(TESTDIR)/%.c,$(TESTBINDIR)/%,$(TEST_SRCS_C)) \
             $(patsubst $(TESTDIR)/%.cpp,$(TESTBINDIR)/%,$(TEST_SRCS_CXX))

# Map source files to the build directory as .o files
OBJS     := $(patsubst $(SRCDIR)/%.c,$(BUILDDIR)/%.o,$(SRCS_C)) \
            $(patsubst $(SRCDIR)/%.cpp,$(BUILDDIR)/%.o,$(SRCS_CXX))

# Generate dependency file names (.d) from object file names
DEPS     := $(OBJS:.o=.d)

# ==============================================================================
# Build Rules
# ==============================================================================

# Default target rule (first rule is executed by default)
all: $(BINDIR)/$(TARGET)

# Linking the final executable
$(BINDIR)/$(TARGET): $(OBJS)
	@$(MKDIR) $(BINDIR)
	$(CXX) $(LDFLAGS) $^ $(LDLIBS) -o $@
	@echo "🎉 Build successful! Executable is at $@"

# Compiling C Source Files
$(BUILDDIR)/%.o: $(SRCDIR)/%.c
	@$(MKDIR) $(dir $@)
	$(CC) $(CFLAGS) -MMD -MP -c $< -o $@

# Compiling C++ Source Files
$(BUILDDIR)/%.o: $(SRCDIR)/%.cpp
	@$(MKDIR) $(dir $@)
	$(CXX) $(CXXFLAGS) -MMD -MP -c $< -o $@

# Include dependency files if they exist (prevents full rebuilds unless needed)
-include $(DEPS)

# ==============================================================================
# Test Rules
# ==============================================================================

# Build C tests
$(TESTBINDIR)/%: $(TESTDIR)/%.c
	@$(MKDIR) $(dir $@)
	$(CC) $(CFLAGS) $< $(LDLIBS) -o $@

# Build C++ tests
$(TESTBINDIR)/%: $(TESTDIR)/%.cpp
	@$(MKDIR) $(dir $@)
	$(CXX) $(CXXFLAGS) $< $(LDLIBS) -o $@

test: $(TEST_BINS)
	@set -e; \
	for test in $(TEST_BINS); do \
		echo "Running $$test..."; \
		./$$test; \
	done
	@echo "All tests passed!"

# ==============================================================================
# Utility Rules
# ==============================================================================

.PHONY: all test clean run

# Run the compiled application
run: all
	./$(BINDIR)/$(TARGET)

# Clean up build artifacts
clean:
	@echo "🧹 Cleaning up build and binary directories..."
	$(RM) $(BUILDDIR) $(BINDIR)
