PWD := $(shell pwd)

SBY_DIR ?= $(PWD)
PASS_DIR ?= $(PWD)/passed_tests
FAIL_DIR ?= $(PWD)/failed_tests

SBY_FILES := $(wildcard $(SBY_DIR)/*.sby)
TEST_NAMES := $(basename $(notdir $(SBY_FILES)))
PASSED_MARKERS := $(addprefix $(PASS_DIR)/, $(addsuffix .passed, $(TEST_NAMES)))

.PHONY: all clean setup

all: setup $(PASSED_MARKERS)
	@echo " All Proofs Passed Successfully " 

setup:	
	@mkdir -p $(PASS_DIR) $(FAIL_DIR)


$(PASS_DIR)/%.passed: $(SBY_DIR)/%.sby | setup
	@rm -rf $(PASS_DIR)/$* $(FAIL_DIR)/$* $(PASS_DIR)/$*.passed $(FAIL_DIR)/$*.failed $(SBY_DIR)/$*_temp
	
	@if sby -f $< -d $(SBY_DIR)/$*_temp ; then \
		mv $(SBY_DIR)/$*_temp $(PASS_DIR)/$*; \
		touch $@; \
		echo "PASSED: $* (Logs saved to $(PASS_DIR)/$*)"; \
	else \
		mv $(SBY_DIR)/$*_temp $(FAIL_DIR)/$*; \
		touch $(FAIL_DIR)/$*.failed; \
		echo "FAILED: $* (Logs saved to $(FAIL_DIR)/$*)"; \
		exit 1; \
	fi

# 3. Clean up the logs and directories once used
clean:
	@echo "Cleaning all test directories and logs..."
	@rm -rf $(PASS_DIR) $(FAIL_DIR) *_temp
	@echo "Workspace is clean."