.PHONY: create_environment calibrate calibration_reports

#################################################################################
# GLOBALS                                                                       #
#################################################################################

## variables
DATA_DIR = data
DATA_RAW_DIR := $(DATA_DIR)/raw
DATA_INTERIM_DIR := $(DATA_DIR)/interim
DATA_PROCESSED_DIR := $(DATA_DIR)/processed

NOTEBOOKS_DIR = notebooks
REPORTS_DIR = reports

define MAKE_DATA_SUB_DIR
$(DATA_SUB_DIR): | $(DATA_DIR)
	mkdir $$@
endef
$(DATA_DIR):
	mkdir $@
$(foreach DATA_SUB_DIR, \
	$(DATA_RAW_DIR) $(DATA_INTERIM_DIR) $(DATA_PROCESSED_DIR), \
	$(eval $(MAKE_DATA_SUB_DIR)))

UCM_CALIBRATION_DATA_DIR := $(DATA_RAW_DIR)/UCM_CalibrationData
INVEST_INPUTS_DIR := $(UCM_CALIBRATION_DATA_DIR)/InVEST_Inputs
T_INPUTS_DIR := $(UCM_CALIBRATION_DATA_DIR)/Twine_UHI_2016
LST_INPUTS_DIR := $(UCM_CALIBRATION_DATA_DIR)/LandSurfaceTemperature2016

#################################################################################
# PROJECT RULES                                                                 #
#################################################################################

# 0. Create a conda environment with the required dependencies
create_environment:
	conda env create -f environment.yml

# 1. Preprocess inputs
## 1.1 Transform ref. et. to GeoTiff and reproject it to the LULC CRS
LULC_ADF := $(INVEST_INPUTS_DIR)/nlcd_2016/hdr.adf
LULC_SRS_WKT := $(DATA_INTERIM_DIR)/lulc-srs.wkt
REF_ET_ADF := $(INVEST_INPUTS_DIR)/et0/et0_july/hdr.adf
REF_ET_TMP_TIF := $(DATA_INTERIM_DIR)/et0_july-tmp.tif
REF_ET_REPROJ_TIF := $(DATA_INTERIM_DIR)/et0_july.tif

$(LULC_SRS_WKT) : $(LULC_ADF) | $(DATA_INTERIM_DIR)
	gdalsrsinfo -o wkt $< > $@
$(REF_ET_REPROJ_TIF): $(REF_ET_ADF) $(LULC_SRS_WKT) | $(DATA_INTERIM_DIR)
	gdal_translate -of GTiff $(REF_ET_ADF) $(REF_ET_TMP_TIF)
	gdalwarp -t_srs $(LULC_SRS_WKT) $(REF_ET_TMP_TIF) $@
	rm $(REF_ET_TMP_TIF)

## 1.2 Transform LST to GeoTiff
LST_ADF := $(LST_INPUTS_DIR)/lst2016_utm_c/hdr.adf
LST_TO_REPROJ_DIR := $(DATA_INTERIM_DIR)/lst-to-reproj
LST_TIF := $(LST_TO_REPROJ_DIR)/lst2016_utm_c.tif

$(LST_TO_REPROJ_DIR): | $(DATA_INTERIM_DIR)
	mkdir $@
$(LST_TIF): $(LST_ADF) $(LULC_SRS_WKT) | $(LST_TO_REPROJ_DIR)
	gdalwarp -t_srs $(LULC_SRS_WKT) $(LST_ADF) $@

# 2. Calibration
## 2.1 Make a list of all the ref. temperature maps against which we calibrate
T_TIF_FILEPATHS := $(addprefix $(T_INPUTS_DIR)/, July4-6_2012_DayTemp1.tif \
	July4-6_2012_NightTemp1.tif JJA_Day_Temp1.tif JJA_Night_Temp1.tif) \
	$(LST_TIF)
## 2.2 Dump the calibration parameters of each calibration 
CALIBRATED_PARAMS_JSON_FILEPATHS := $(addprefix $(DATA_PROCESSED_DIR)/, \
	$(addsuffix .json, $(basename $(notdir $(T_TIF_FILEPATHS)))))

BIOPHYSICAL_TABLE_CSV := $(INVEST_INPUTS_DIR)/ucm_200316__NLCD_CURRENT.csv
T_REPROJ_TIF = $(DATA_INTERIM_DIR)/$(notdir $(T_TIF))
define CALIBRATION_RUN
$(T_REPROJ_TIF): $(T_TIF) $(LULC_SRS_WKT)
	gdalwarp -t_srs $(LULC_SRS_WKT) $(T_TIF) $$@
$(DATA_PROCESSED_DIR)/$(notdir $(basename $(T_REPROJ_TIF))).json: \
	$(REF_ET_REPROJ_TIF) $(T_REPROJ_TIF) | $(DATA_PROCESSED_DIR)
	invest-ucm-calibration $(LULC_ADF) $(BIOPHYSICAL_TABLE_CSV) factors \
		--ref-et-raster-filepaths $(REF_ET_REPROJ_TIF) \
		--t-raster-filepaths $(T_REPROJ_TIF) --dst-filepath $$@
endef

$(foreach T_TIF, $(T_TIF_FILEPATHS), $(eval $(CALIBRATION_RUN)))

calibrate: $(CALIBRATED_PARAMS_JSON_FILEPATHS)

# 3. Notebooks
CALIBRATION_REPORT_IPYNB = $(NOTEBOOKS_DIR)/calibration-report.ipynb
NOTEBOOKS_OUTPUT_DIR := $(NOTEBOOKS_DIR)/output

$(NOTEBOOKS_OUTPUT_DIR): | $(NOTEBOOKS_DIR)
	mkdir $@
$(REPORTS_DIR):
	mkdir $@


T_RASTER_TIF = $(DATA_INTERIM_DIR)/$(CALIBRATION_FILENAME).tif
CALIBRATED_PARAMS_JSON = $(DATA_PROCESSED_DIR)/$(CALIBRATION_FILENAME).json
NOTEBOOK_OUT_IPYNB = $(NOTEBOOKS_OUTPUT_DIR)/$(CALIBRATION_FILENAME).ipynb
NOTEBOOK_OUT_PDF = $(REPORTS_DIR)/$(CALIBRATION_FILENAME).pdf
define CALIBRATION_REPORT
$(NOTEBOOK_OUT_IPYNB): $(LULC_ADF) $(BIOPHYSICAL_TABLE_CSV) \
	$(REF_ET_REPROJ_TIF) $(T_RASTER_TIF) $(CALIBRATED_PARAMS_JSON) \
	$(CALIBRATION_REPORT_IPYNB) | $(NOTEBOOKS_OUTPUT_DIR)
	papermill $(CALIBRATION_REPORT_IPYNB) $$@ \
		-p lulc_raster_filepath $(LULC_ADF) \
		-p biophysical_table_filepath $(BIOPHYSICAL_TABLE_CSV) \
		-p ref_et_raster_filepath $(REF_ET_REPROJ_TIF) \
		-p t_raster_filepath $(T_RASTER_TIF) \
		-p calibrated_params_filepath $(CALIBRATED_PARAMS_JSON)
$(NOTEBOOK_OUT_PDF): $(NOTEBOOK_OUT_IPYNB) | $(REPORTS_DIR)
	jupyter-nbconvert $$< --to pdf --output-dir $(REPORTS_DIR)
endef

CALIBRATION_FILENAMES := $(notdir $(basename \
	$(CALIBRATED_PARAMS_JSON_FILEPATHS)))
$(foreach CALIBRATION_FILENAME, $(CALIBRATION_FILENAMES), \
	$(eval $(CALIBRATION_REPORT)))
CALIBRATION_REPORTS_PDF_FILEPATHS := $(addprefix $(REPORTS_DIR)/, \
	$(addsuffix .pdf, $(notdir $(basename $(CALIBRATION_FILENAMES)))))

calibration_reports: $(CALIBRATION_REPORTS_PDF_FILEPATHS)

#################################################################################
# Self Documenting Commands                                                     #
#################################################################################

.DEFAULT_GOAL := help

# Inspired by <http://marmelab.com/blog/2016/02/29/auto-documented-makefile.html>
# sed script explained:
# /^##/:
# 	* save line in hold space
# 	* purge line
# 	* Loop:
# 		* append newline + line to hold space
# 		* go to next line
# 		* if line starts with doc comment, strip comment character off and loop
# 	* remove target prerequisites
# 	* append hold space (+ newline) to line
# 	* replace newline plus comments by `---`
# 	* print line
# Separate expressions are necessary because labels cannot be delimited by
# semicolon; see <http://stackoverflow.com/a/11799865/1968>
.PHONY: help
help:
	@echo "$$(tput bold)Available rules:$$(tput sgr0)"
	@echo
	@sed -n -e "/^## / { \
		h; \
		s/.*//; \
		:doc" \
		-e "H; \
		n; \
		s/^## //; \
		t doc" \
		-e "s/:.*//; \
		G; \
		s/\\n## /---/; \
		s/\\n/ /g; \
		p; \
	}" ${MAKEFILE_LIST} \
	| LC_ALL='C' sort --ignore-case \
	| awk -F '---' \
		-v ncol=$$(tput cols) \
		-v indent=19 \
		-v col_on="$$(tput setaf 6)" \
		-v col_off="$$(tput sgr0)" \
	'{ \
		printf "%s%*s%s ", col_on, -indent, $$1, col_off; \
		n = split($$2, words, " "); \
		line_length = ncol - indent; \
		for (i = 1; i <= n; i++) { \
			line_length -= length(words[i]) + 1; \
			if (line_length <= 0) { \
				line_length = ncol - indent - length(words[i]) - 1; \
				printf "\n%*s ", -indent, " "; \
			} \
			printf "%s ", words[i]; \
		} \
		printf "\n"; \
	}' \
	| more $(shell test $(shell uname) = Darwin && echo '--no-init --raw-control-chars')
