[![GitHub license](https://img.shields.io/github/license/martibosch/uhi-twin-cities.svg)](https://github.com/martibosch/uhi-twin-cities/blob/master/LICENSE)

# UHI Twin Cities

Calibration of the InVEST urban cooling model in Twin Cities, USA

## Instructions to reproduce

### 1. Clone the repository

You can use git to clone this repository as in:

```bash
git clone https://github.com/martibosch/uhi-twin-cities.git
```

or [download as a zip file](https://github.com/martibosch/uhi-twin-cities/archive/master.zip) and extract it.

### 2. Software requirements

First of all, conda is required to automatically install all the sofware dependencies. See [its installation page](https://docs.conda.io/projects/conda/en/latest/user-guide/install/) and follow the steps to install it in your operating system.

Additionally, [GNU Make](https://www.gnu.org/software/make/) is used to manage the execution of the calibration workflow, which is usually built-in with Linux and OSX systems. **Windows users** can install it from the Anaconda prompt as in:

```bash
# ACHTUNG: You only need to run this in Windows
conda install -c conda-forge make
```

Then, from the root of this repository, you can create a conda environment with all the required software dependencies as in:

```bash
make create_environment
```

and then activate it as in:

```bash
conda activate uhi-twin-cities
```

### 3. Data requirements

Copy the `UCM_CalibrationData` from the Google Drive to the `data/raw` directory of this repository so that the directory structure is of the form:

```
|─ data
|  └─ raw
|     └─ UCM_CalibrationData
|        |─ InVEST_Inputs
|        |─ Twine_UHI_2016
|        └─ LandSurfaceTemperature2016
|
|─ .gitignore
|─ LICENSE
|─ Makefile
|─ README.md
└─ environment.yml
```

### 4. Calibrate the model

The calibration of the urban cooling model for the `July4-6_2012_DayTemp1.tif`, `July4-6_2012_NightTemp1.tif`, `JJA_Day_Temp1.tif`, `JJA_Night_Temp1.tif` and `lst2016_utm_c/hdr.adf` reference temperature rasters can be executed as in:

```bash
make calibrate
```

which will dump the calibrated parameters for each file in the `data/processed` directory (which will be created automatically if it does not exist).

### 5. Generate the calibration reports

Reports for the calibration of the urban cooling model for each of the reference temperature rasters can be obtained as in:

```bash
make calibration_reports
```

which will generate a PDF calibration report and dump it to the `reports` directory (which will be created automatically if it does not exist).


--------

Project based on the [cookiecutter data science project template](https://drivendata.github.io/cookiecutter-data-science). #cookiecutterdatascience
