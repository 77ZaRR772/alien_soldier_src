# Alien Soldier (J) Makefile
# Build configuration for AS assembler

# Tools
AS_BIN = bin/asw.exe
P2BIN = bin/p2bin.exe
AS_ARGS = -maxerrors 2

# Files
SRC = alien_soldier_j.s
OBJ = alien_soldier_j.p
ROM = asbuilt.bin
ORIG_ROM = alien_soldier_j.bin

# Directories
DATA_DIR = data
SRC_DIR = src
SCRIPTS_DIR = scripts
BIN_DIR = bin

# Tile addresses file
TILES_ADDRS = $(DATA_DIR)/tiles_addrs.txt

# Default target
.PHONY: all
all: build

# Build ROM from assembly source
.PHONY: build
build:
	@echo "Building ROM..."
	python $(SCRIPTS_DIR)/build_rom.py \
		--source $(SRC) \
		--output $(ROM) \
		--as-bin $(AS_BIN) \
		--p2bin $(P2BIN) \
		--as-args "$(AS_ARGS)"
	@echo ""
	@echo "Build complete: $(ROM)"

# Split original ROM into data files
.PHONY: split
split:
	@echo "Splitting ROM data..."
	@python $(SCRIPTS_DIR)/split_data_from_rom.py \
		--rom-file $(ORIG_ROM) \
		--output $(DATA_DIR) \
		--addrs $(TILES_ADDRS)
	@echo ""
	@echo "Split complete!"

# Clean build artifacts and temp files
.PHONY: clean
clean:
	@python $(SCRIPTS_DIR)/clean_project.py

# Analysis configuration
# Workflow directory (for reports, procedure lists, etc.)
WORKFLOW_DIR = workflow

# Movie files for each analysis type
MOVIE_FILE_tas = movies/dammit,truncated-aliensoldier.gmv
MOVIE_FILE_longplay = movies/alien_soldier_j_longplay.gmv
MOVIE_FILE_menus = movies/alien_soldier_j_menus.gmv

# Max frames per movie type (0 = play until end)
MAX_FRAMES_tas = 90000
MAX_FRAMES_longplay = 0
MAX_FRAMES_menus = 0
ANALYSIS_WORKERS = 24
ANALYSIS_GRID_COLS = 6
ANALYSIS_FRAMESKIP = 8
ANALYSIS_INTERVAL = 20
ANALYSIS_MAX_FRAMES = 90000
ANALYSIS_MAX_DIFFS = 10
ANALYSIS_DIFF_COLOR = pink
PROCEDURES_FILE = $(WORKFLOW_DIR)/unanalyzed_procedures.txt

# Generate reference screenshots + memory dumps
# Usage: make reference MOVIE=tas|longplay|menus
.PHONY: reference
reference:
ifndef MOVIE
	@echo "ERROR: MOVIE parameter required!"
	@echo ""
	@echo "Usage: make reference MOVIE=<type>"
	@echo ""
	@echo "Examples:"
	@echo "  make reference MOVIE=tas      - TAS speedrun reference"
	@echo "  make reference MOVIE=longplay - Longplay reference"
	@echo "  make reference MOVIE=menus    - Menu exploration reference"
	@exit 1
else
	@echo "Generating reference screenshots and memory dumps from $(MOVIE)..."
	python -c "import os; os.makedirs('reference/$(MOVIE)', exist_ok=True)"
	"$(GENS_EXE)" \
		-rom $(ROM) \
		-play $(MOVIE_FILE_$(MOVIE)) \
		-screenshot-interval $(ANALYSIS_INTERVAL) \
		-screenshot-dir reference/$(MOVIE) \
		$(if $(MAX_FRAMES_$(MOVIE)),-max-frames $(MAX_FRAMES_$(MOVIE)),) \
		-save-state-dumps \
		-turbo \
		-frameskip 0 \
		-nosound
	@echo "Reference saved to reference/$(MOVIE)/"
endif

# Analyze procedures for visual/memory impact
# Usage: make analyze MOVIE=tas|longplay|menus
.PHONY: analyze
analyze:
ifndef MOVIE
	@echo "ERROR: MOVIE parameter required!"
	@echo ""
	@echo "Usage: make analyze MOVIE=<type>"
	@echo ""
	@echo "Examples:"
	@echo "  make analyze MOVIE=tas      - Analyze with TAS speedrun"
	@echo "  make analyze MOVIE=longplay - Analyze with longplay"
	@echo "  make analyze MOVIE=menus    - Analyze with menu exploration"
	@exit 1
else
	@echo "Analyzing procedures with $(MOVIE) ($(ANALYSIS_WORKERS) workers)..."
	python $(SCRIPTS_DIR)/analyze_procedures.py \
		--project-dir . \
		--source $(SRC) \
		--rom $(ROM) \
		--movie $(MOVIE_FILE_$(MOVIE)) \
		--reference reference/$(MOVIE) \
		--diffs diffs/$(MOVIE) \
		--procedures-file $(PROCEDURES_FILE) \
		--workers $(ANALYSIS_WORKERS) \
		--grid-cols $(ANALYSIS_GRID_COLS) \
		--frameskip $(ANALYSIS_FRAMESKIP) \
		--interval $(ANALYSIS_INTERVAL) \
		$(if $(MAX_FRAMES_$(MOVIE)),--max-frames $(MAX_FRAMES_$(MOVIE)),) \
		--max-diffs $(ANALYSIS_MAX_DIFFS) \
		--diff-color $(ANALYSIS_DIFF_COLOR)
endif

# Find which procedures are not yet analyzed and save to file
.PHONY: find-unanalyzed
find-unanalyzed:
	@echo "Finding unanalyzed procedures..."
	@python -c "import os; os.makedirs('$(WORKFLOW_DIR)', exist_ok=True)"
	@python $(SCRIPTS_DIR)/find_unnamed_procedures.py \
		--list \
		--exclude-analyzed analysis_results.csv \
		--output $(PROCEDURES_FILE)
	@echo "Saved to $(PROCEDURES_FILE)"

# Generate analysis report
# Usage: make report MOVIE=tas|longplay|menus
.PHONY: report
report:
ifndef MOVIE
	@echo "ERROR: MOVIE parameter required!"
	@echo ""
	@echo "Usage: make report MOVIE=<type>"
	@echo ""
	@echo "Examples:"
	@echo "  make report MOVIE=tas      - Generate TAS report"
	@echo "  make report MOVIE=longplay - Generate longplay report"
	@echo "  make report MOVIE=menus    - Generate menus report"
	@exit 1
else
	@echo "Generating $(MOVIE) analysis report..."
	@python -c "import os; os.makedirs('$(WORKFLOW_DIR)', exist_ok=True)"
	python $(SCRIPTS_DIR)/generate_analysis_report.py --project-dir . --movie $(MOVIE) --output-dir $(WORKFLOW_DIR)
	@echo "Report saved: $(WORKFLOW_DIR)/analysis_report_$(MOVIE).txt / .csv"
endif

# Compare built ROM with original
.PHONY: compare
compare:
	@python $(SCRIPTS_DIR)/compare_roms.py \
		--built $(ROM) \
		--original $(ORIG_ROM) \
		--project-dir .

# ============================================================================
# DOCUMENTATION WORKFLOW
# ============================================================================
# 1. make set-movie MOVIE=tas     - Set current movie type for workflow
# 2. make prepare-batch COUNT=40  - Prepare batch of procedures to document
# 3. [Claude creates workflow/rename_batch.csv with new names]
# 4. make rename                  - Apply renames and mark as processed
# ============================================================================

# Set movie type for documentation workflow
# Usage: make set-movie MOVIE=tas|longplay|menus
.PHONY: set-movie
set-movie:
ifndef MOVIE
	@echo "ERROR: MOVIE parameter required!"
	@echo ""
	@echo "Usage: make set-movie MOVIE=<type>"
	@echo ""
	@echo "Examples:"
	@echo "  make set-movie MOVIE=tas"
	@exit 1
else
	@python -c "import os; os.makedirs('$(WORKFLOW_DIR)', exist_ok=True)"
	@echo $(MOVIE) > $(WORKFLOW_DIR)/.movie
	@echo "Movie type set to: $(MOVIE)"
	@echo "Saved to $(WORKFLOW_DIR)/.movie"
endif

# Show current movie setting
.PHONY: show-movie
show-movie:
	@if [ -f $(WORKFLOW_DIR)/.movie ]; then \
		echo "Current movie: $$(cat $(WORKFLOW_DIR)/.movie)"; \
	else \
		echo "No movie set. Use: make set-movie MOVIE=tas"; \
	fi

# Prepare batch of procedures for documentation
# Usage: make prepare-batch COUNT=40
BATCH_COUNT ?= 40
.PHONY: prepare-batch
prepare-batch:
	@if [ ! -f $(WORKFLOW_DIR)/.movie ]; then \
		echo "ERROR: No movie set!"; \
		echo "First run: make set-movie MOVIE=tas"; \
		exit 1; \
	fi
	@echo "Preparing batch of $(BATCH_COUNT) procedures..."
	python $(SCRIPTS_DIR)/prepare_batch.py \
		--report $(WORKFLOW_DIR)/analysis_report_$$(cat $(WORKFLOW_DIR)/.movie).csv \
		--count $(BATCH_COUNT) \
		--output $(WORKFLOW_DIR)/batch_procedures.txt \
		--source $(SRC)
	@echo ""
	@echo "Batch prepared: $(WORKFLOW_DIR)/batch_procedures.txt"
	@echo ""
	@echo "Next steps:"
	@echo "  1. Claude reads $(WORKFLOW_DIR)/batch_procedures.txt"
	@echo "  2. Claude creates $(WORKFLOW_DIR)/rename_batch.csv with columns:"
	@echo "     old_name,new_name,description"
	@echo "  3. Run: make rename"

# Apply renames from rename_batch.csv and mark as processed
.PHONY: rename
rename:
	@if [ ! -f $(WORKFLOW_DIR)/.movie ]; then \
		echo "ERROR: No movie set!"; \
		exit 1; \
	fi
	@if [ ! -f $(WORKFLOW_DIR)/rename_batch.csv ]; then \
		echo "ERROR: $(WORKFLOW_DIR)/rename_batch.csv not found!"; \
		echo "Create it with columns: old_name,new_name,description"; \
		exit 1; \
	fi
	@echo "Applying renames from $(WORKFLOW_DIR)/rename_batch.csv..."
	python $(SCRIPTS_DIR)/rename_procedures.py \
		--source $(SRC) \
		--database $(WORKFLOW_DIR)/rename_batch.csv \
		--report $(WORKFLOW_DIR)/analysis_report_$$(cat $(WORKFLOW_DIR)/.movie).csv
	@echo ""
	@echo "Renames applied! Next steps:"
	@echo "  1. Review changes: git diff $(SRC)"
	@echo "  2. Build and test: make build"
	@echo "  3. Commit: git add $(SRC) && git commit"

# Gens emulator paths
GENS_DIR = gens-rerecording/Gens-rr
GENS_SLN = $(GENS_DIR)/gens_vc10.sln
GENS_EXE = $(GENS_DIR)/Output/Gens.exe
MSBUILD = C:/Program Files/Microsoft Visual Studio/2022/Community/MSBuild/Current/Bin/MSBuild.exe

# Debug: Build ROM and run with memory dump comparison mode
# Compares memory dumps against reference, saves first diff and exits
# Usage: make debug MOVIE=tas|longplay|menus
.PHONY: debug
debug: build
ifndef MOVIE
	@echo "ERROR: MOVIE parameter required!"
	@echo ""
	@echo "Usage: make debug MOVIE=<type>"
	@echo ""
	@echo "Examples:"
	@echo "  make debug MOVIE=tas"
	@exit 1
else
	@echo "Running $(MOVIE) with memory dump comparison (debug mode)..."
	python -c "import os; os.makedirs('diffs/$(MOVIE)', exist_ok=True); os.makedirs('reports', exist_ok=True)"
	"$(GENS_EXE)" \
		-rom $(ROM) \
		-play $(MOVIE_FILE_$(MOVIE)) \
		-screenshot-interval $(ANALYSIS_INTERVAL) \
		-screenshot-dir diffs/$(MOVIE) \
		-reference-dir reference/$(MOVIE) \
		$(if $(MAX_FRAMES_$(MOVIE)),-max-frames $(MAX_FRAMES_$(MOVIE)),) \
		-max-diffs 1 \
		-compare-state-dumps \
		-turbo \
		-frameskip 0 \
		-nosound
	@echo ""
	@echo "Emulator run complete. Generating comparison report..."
	@python $(SCRIPTS_DIR)/compare_states.py \
		--diffs-dir diffs/$(MOVIE) \
		--reference-dir reference/$(MOVIE) \
		--output-dir reports
	@echo ""
	@echo "Debug complete! Check:"
	@echo "  - diffs/$(MOVIE)/*.genstate - Memory dump at first difference"
	@echo "  - diffs/$(MOVIE)/*.png - Screenshot at first difference"
	@echo "  - reports/diff_frame_*.md - Detailed LLM-friendly analysis report"
endif

# Stop all running emulators and analysis
.PHONY: stop
stop:
	@echo "Stopping analysis and emulators..."
	-taskkill /F /IM Gens.exe 2>nul
	-taskkill /F /IM python.exe 2>nul
	@echo "Done"

# Build Gens emulator
.PHONY: build-gens
build-gens:
	@echo "Building Gens emulator..."
	"$(MSBUILD)" "$(GENS_SLN)" -p:Configuration=Release -p:Platform=Win32 -p:PlatformToolset=v143 -t:Build -v:minimal
	@echo "Build complete: $(GENS_EXE)"

# Help
.PHONY: help
help:
	@echo "Alien Soldier (J) Build System"
	@echo ""
	@echo "Basic commands:"
	@echo "  make build              - Assemble and build ROM (default)"
	@echo "  make compare            - Compare built ROM with original"
	@echo "  make split              - Extract data from original ROM"
	@echo "  make clean              - Remove all build artifacts and extracted data"
	@echo ""
	@echo "Analysis workflow (requires MOVIE=tas|longplay|menus):"
	@echo "  1. make find-unanalyzed        - Generate list of unanalyzed procedures"
	@echo "  2. make reference MOVIE=tas    - Generate reference screenshots"
	@echo "  3. make analyze MOVIE=tas      - Analyze procedures"
	@echo "  4. make report MOVIE=tas       - Generate analysis report"
	@echo ""
	@echo "Documentation workflow (Claude + human):"
	@echo "  1. make set-movie MOVIE=tas    - Set movie type for workflow"
	@echo "  2. make prepare-batch COUNT=40 - Prepare batch of procedures"
	@echo "     -> Claude reads workflow/batch_procedures.txt"
	@echo "     -> Claude creates workflow/rename_batch.csv"
	@echo "  3. make rename                 - Apply renames and mark processed"
	@echo "  4. make build && make compare"
	@echo "  5. git commit"
	@echo ""
	@echo "Memory-level debugging:"
	@echo "  1. make reference MOVIE=tas    - Generate reference"
	@echo "  2. [modify ROM and rebuild]"
	@echo "  3. make debug MOVIE=tas        - Detect first memory difference"
	@echo ""
	@echo "Utilities:"
	@echo "  make show-movie         - Show current movie setting"
	@echo "  make stop               - Stop all running Gens emulators"
	@echo "  make build-gens         - Build Gens emulator (VS2022)"
	@echo ""
	@echo "MOVIE types: tas, longplay, menus"
	@echo "Workflow dir: $(WORKFLOW_DIR)/"
