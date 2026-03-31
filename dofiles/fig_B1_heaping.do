cap log close
local LOGDIR "$PROJ/log"
local FIGDIR "$PROJ/figure"
local WORKDIR "$DATA_WORK"

cap mkdir "`LOGDIR'"
cap mkdir "`FIGDIR'"

log using "`LOGDIR'/fig_B1_heaping", replace

version 17
clear all
set more off
/*------------------------------------------------------------
Stata do-file
Figure B1: Heaping / rounding diagnostics (mod10, mod100)
- Consistent with:
	- cr_dta.do: produces kpi_tidy_for_bunching.dta with r_dir, ok_b, target_dir, actual_dir, normalized 単位
	- saez_260328.do: uses ok_b + r_dir (no re-definition)
- Outputs (fixed file names):
	- figure/fig_B1_target_mod10_pct.png
	- figure/fig_B1_target_mod10_nonpct.png
	- figure/fig_B1_actual_mod10_pct.png
	- figure/fig_B1_actual_mod10_nonpct.png
	- figure/fig_B1_actual_mod100_coarse_pct.png
	- figure/fig_B1_actual_mod100_coarse_nonpct.png
------------------------------------------------------------*/



*----------------------------
* 1. Load tidy data (created by cr_dta.do)
*----------------------------
use "`WORKDIR'/kpi_tidy_for_bunching.dta", clear

*----------------------------
* 2. Check required variables (defined in cr_dta.do)
*----------------------------
foreach v in ok_b target_dir actual_dir r_dir {
	capture confirm variable `v'
	if _rc {
		di as error "Missing variable `v'. Re-run cr_dta.do and re-save kpi_tidy_for_bunching.dta."
		exit 198
	}
}

capture confirm string variable 単位
if _rc {
	di as error "Missing string variable 単位. Re-run cr_dta.do (unit normalization should happen there)."
	exit 198
}

count if ok_b
local N_okb = r(N)
di as txt "Obs in bunching sample (ok_b): `N_okb'"

keep if ok_b

*----------------------------
* 3. Define % vs non-% split
*----------------------------
* Assumes 単位 has already been normalized ("％" -> "%") in cr_dta.do
* If there are other percent-like strings, extend this condition.
gen byte is_pct = (単位=="%")
label define is_pct 0 "non-%" 1 "%"
label values is_pct is_pct

*----------------------------
* 4. MOD 10 / MOD 100 setup
*----------------------------
* This version treats target_dir/actual_dir as integer-valued (or close).
* Diagnostics: integer-ness by group.
gen byte target_is_int = (target_dir == floor(target_dir)) if !missing(target_dir)
gen byte actual_is_int = (actual_dir == floor(actual_dir)) if !missing(actual_dir)

tab target_is_int is_pct, col
tab actual_is_int is_pct, col

* Use integer part for mod (robust to small floating errors)
gen double target_i = floor(target_dir)
gen double actual_i = floor(actual_dir)

gen int target_mod10 = mod(target_i, 10) if !missing(target_i)
gen int actual_mod10 = mod(actual_i, 10) if !missing(actual_i)
gen int actual_mod100 = mod(actual_i, 100) if !missing(actual_i)

*----------------------------
* 5. Plot MOD 10 distributions (share)
*----------------------------
tempfile base
save `base', replace

foreach g in 1 0 {
	use `base', clear
	local suf = cond(`g'==1, "pct", "nonpct")
	keep if is_pct==`g'

	* --- target mod10 ---
	preserve
		keep if inrange(target_mod10,0,9)
		contract target_mod10
		egen N = total(_freq)
		gen share = _freq / N

		twoway bar share target_mod10, ///
			xlabel(0(1)9) ///
			ytitle("Share") xtitle("mod10") ///
			title("Figure B1: target mod10 (`: label is_pct `g'')") ///
			note("Sample: ok_b==1; N(ok_b)=`N_okb'") ///
			graphregion(color(white))

		graph export "`FIGDIR'/fig_B1_target_mod10_`suf'.png", replace width(2400)
	restore

	* --- actual mod10 ---
	preserve
		keep if inrange(actual_mod10,0,9)
		contract actual_mod10
		egen N = total(_freq)
		gen share = _freq / N

		twoway bar share actual_mod10, ///
			xlabel(0(1)9) ///
			ytitle("Share") xtitle("mod10") ///
			title("Figure B1: actual mod10 (`: label is_pct `g'')") ///
			note("Sample: ok_b==1; N(ok_b)=`N_okb'") ///
			graphregion(color(white))

		graph export "`FIGDIR'/fig_B1_actual_mod10_`suf'.png", replace width(2400)
	restore
}

*----------------------------
* 6. MOD 100 (coarse bins for actual): 00 / 10..90 / other
*----------------------------
use `base', clear

gen byte actual_mod100_cat = .
replace actual_mod100_cat = 0 if actual_mod100==0
replace actual_mod100_cat = 1 if inlist(actual_mod100,10,20,30,40,50,60,70,80,90)
replace actual_mod100_cat = 2 if missing(actual_mod100_cat) & !missing(actual_mod100)

label define mod100cat 0 "00" 1 "10..90" 2 "other"
label values actual_mod100_cat mod100cat

foreach g in 1 0 {
	preserve
		local suf = cond(`g'==1, "pct", "nonpct")
		keep if is_pct==`g'
		keep if !missing(actual_mod100_cat)

		contract actual_mod100_cat
		egen N = total(_freq)
		gen share = _freq / N

		graph bar (mean) share, over(actual_mod100_cat, sort(1)) ///
			ytitle("Share") ///
			title("Figure B1: actual mod100 (coarse) (`: label is_pct `g'')") ///
			note("Sample: ok_b==1; N(ok_b)=`N_okb'") ///
			graphregion(color(white))

		graph export "`FIGDIR'/fig_B1_actual_mod100_coarse_`suf'.png", replace width(2400)
	restore
}

di as txt "Done: Figure B1 exported to `FIGDIR'/"

/*
NOTE: If target_dir/actual_dir are NOT integer-like
---------------------------------------------------
If many values are decimals, mod on integer part may be misleading.
In that case, define a scale factor and use scaled integers.
Example (one decimal place):
	gen int actual_mod10 = mod(round(actual_dir*10), 10)
This would visualize heaping at x.x0, x.x1, ..., x.x9.
*/