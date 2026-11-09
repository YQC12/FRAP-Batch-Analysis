# FRAP Batch Analysis (MATLAB)

A two-step MATLAB workflow for preprocessing fluorescence recovery after photobleaching (FRAP) measurements and batch fitting recovery curves. The first script removes a detected interval of laser-associated signal artifacts and reconstructs the time axis; the second normalizes the fluorescence recovery data, fits a single-exponential model, and exports plots and quantitative parameters.

> **Status:** Research-use scripts provided as-is. Results should be visually inspected and validated against the experimental acquisition settings before quantitative interpretation. This release does **not** calculate viscosity.

## Workflow

```text
Raw FRAP Excel files (*.xlsx; fluorescence intensity in column 3)
    |
    v
1. FRAPdata_TimeRelabel_261109.m
   Detect and remove a laser-associated signal interval;
   reconstruct time using a user-defined sampling interval
    |
    v
Cleaned tab-delimited TXT files (time in seconds, intensity)
    |
    v
2. FRAP_Fitting_Batch_Analysis_261109.m
   Normalize, fit recovery, calculate parameters
    |
    v
Per-file Excel tables and PNG figures + batch summary Excel
```

## Requirements

- MATLAB with `readmatrix`, `writematrix`, `readtable`/`writetable` support (the scripts use `readmatrix`, `writematrix`, `writetable`, `table`).
- **Curve Fitting Toolbox** for `fittype`, `fitoptions`, and `fit` in step 2.
- Input Excel files must contain at least three columns; the first script reads **column 3** as fluorescence intensity.

## Step 1 — Remove laser-associated artifacts and relabel time

Open and run `FRAPdata_TimeRelabel_261109.m` in MATLAB. In the dialog enter:

| Field | Meaning | Example |
|---|---|---|
| Pathway of Fold | Folder containing the input `.xlsx` files | `C:\FRAP\raw` |
| DataLength | Number of rows to take from the numeric matrix returned by `readmatrix` | `200` |
| IntervalTime(sec) | Sampling interval used to rebuild the time axis, in seconds | `0.1` |

For each `.xlsx` file in the folder, the script:

1. Reads the first `DataLength` rows of the numeric matrix and extracts column 3.
2. Finds the **largest positive first difference within the first 18 differences** (`max(diffData(1:18))`).
3. Finds the global minimum intensity index, and deletes the interval from the detected rise index through the sample immediately preceding that minimum.
4. Reconstructs time with the global minimum in the cleaned data at **t = 0**, using `IntervalTime(sec)`.
5. Writes a two-column, tab-delimited `.txt` file **into the same input folder**, retaining the original base filename.

**Important:** This is a heuristic based on signal shape, not a laser trigger or instrument metadata. Check the removed interval and resulting curve for each acquisition. The first 18 differences must exist; `DataLength` must not exceed available numeric rows. Files with different acquisition timing or laser artifacts may require modification of the detection rule.

## Step 2 — FRAP curve fitting and batch export

Run `FRAP_Fitting_Batch_Analysis_261109.m`. Enter:

| Field | Meaning | Example |
|---|---|---|
| Pathway of Folder | Folder containing the cleaned `.txt` files | `C:\FRAP\raw` |
| Bleach Radius (um) | Bleached-region radius in micrometers | `0.26` |
| Export Name | Name of the output subfolder and summary prefix | `FRAP_results` |

Each input `.txt` must have at least two numeric columns: **time (seconds)** and **fluorescence intensity**. The script removes rows containing nonfinite values.

### Normalization and fitting

The current script identifies `F0` as the **global minimum intensity** and `StartPoint` as its index. It defines `Fpre` as the mean intensity of **all preceding rows**. Recovery begins at `StartPoint`, and its time is reset to zero.

```text
F_normalized(t) = [F(t) - F0] / [Fpre - F0]
F_fit(t)        = a * (1 - exp(-b*t))
```

- `a`: fitted mobile fraction (bounded to 0–1)
- `b`: fitted recovery rate constant (bounded to 0–10 s^-1)
- Recovery half-time (s): `ln(2)/b`
- Mobile fraction (%): `100*a`
- Immobile fraction (%): `100*(1-a)`
- Diffusion coefficient (um^2/min): `(0.88*w^2)/(4*HalfTime)*60`, where `w` is bleach radius in um
- `R2`: coefficient of determination from the fit

The initial estimate of `a` is based on the final 10% of normalized data (at least 3 points), clamped to 0.01–0.99. The initial estimate of `b` is 0.05 s^-1.

### Outputs

The output subfolder is `<input folder>/<Export Name>/`:

| Output | Description |
|---|---|
| `Normalized_Intensity_<name>.png` | Normalized recovery intensity (%) |
| `Normalized_<name>.xlsx` | Time, raw recovery intensity, normalized intensity, normalized percent |
| `Fitting_<name>.png` | Experimental points, fitted curve, HalfTime, D, Mf, R2 |
| `<name>_FRAP_Result.xlsx` | Per-file fitted parameters, Fpre, F0, a, b |
| `<Export Name>_FRAP_Summary.xlsx` | Batch summary with filename, HalfTime, D, Mf, IMf, R2, status |

The script records an error message for individual failed files and continues processing the batch. It does not export viscosity.

## Important limitations and quality control

- The preprocessing script uses a hard-coded **18-difference search window** and column 3; adapt these only after verifying your acquisition format.
- The fitting script uses the **global minimum** to identify the bleach point. A later noise spike can be mistaken for the bleach minimum.
- `Fpre` includes every measurement before the minimum, potentially including samples acquired during bleaching. Check the raw trace and consider defining pre-bleach frames explicitly for publication-quality analysis.
- The single-exponential model assumes a simple recovery process. It may not describe all diffusion/binding behaviors.
- The diffusion formula is model- and geometry-dependent; verify its suitability for the optical setup and bleaching geometry. A fitted value at a parameter bound, or `b = 0`, needs special scrutiny.
- Inspect all plots, especially incomplete recovery, noisy curves, movement, and poor fits. R2 alone is not sufficient quality control.
- Example data are provided for illustrating file structure; no claim is made that the example has been experimentally validated or that the scripts have been executed successfully in MATLAB in this repository.

## Example input

`example_data/0.xlsx` is a supplied example Excel file. To try the workflow, copy it to a separate working folder, inspect its numeric columns and row count, and run Step 1 there. Keep generated outputs out of the source-code directory.

## Citation

If these scripts support a publication, cite the associated paper when available and provide the repository URL and a version-specific DOI (for example, from Zenodo) in your Code Availability statement.

## License

See `LICENSE` after a license has been selected and added by the repository owner. Until then, no open-source reuse license is granted by this README.
