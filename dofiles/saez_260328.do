/********************************************************************
 Saez-style bunching estimator for EBPM KPI achievement ratios
 Base spec A + robustness B and C

 A: bw=0.005, window=[0.98,1.02], fit range=[0.8,1.2], deg=3
 B: bw=0.002, window=[0.98,1.02], fit range=[0.8,1.2], deg=3
 C: bw=0.005, window=[0.97,1.03], fit range=[0.8,1.2], deg=3
********************************************************************/

cap log close
log using "$PROJ\log\saez_260328",replace

clear all
set more off
version 17


*----------------------------
* 0) Load tidy data
*----------------------------
use "$DATA_WORK\kpi_tidy_for_bunching.dta", clear
sum

*----------------------------
* 1) Direction adjustment + clean sample for bunching
*----------------------------
* normalize unit symbol (optional)
capture confirm string variable 単位
if !_rc {
    replace 単位 = subinstr(単位, "％", "%", .) if !missing(単位)
}

* direction-adjusted target/actual
gen double target_dir = target
gen double actual_dir = actual
replace target_dir = -target if 改善の上向き下向き=="下がると良い指標" & !missing(target)
replace actual_dir = -actual if 改善の上向き下向き=="下がると良い指標" & !missing(actual)

* achievement ratio (direction-adjusted)
gen double r_dir = actual_dir/target_dir if !missing(actual_dir) & !missing(target_dir) & target_dir!=0
label var r_dir "achievement ratio, direction-adjusted (1=100%)"

* clean sample
gen byte ok = 1
replace ok = 0 if missing(target_dir) | missing(actual_dir)
replace ok = 0 if target_dir<=0
replace ok = 0 if actual_dir<0
replace r_dir = . if !ok

gen byte ok_b = ok
replace ok_b = 0 if missing(r_dir)
replace ok_b = 0 if r_dir<=0 | r_dir>3   // trimming for bunching

di as txt "N (ok_b) = " _N - sum(ok_b==0)  // rough; may show missing; optional
count if ok_b
di as txt "Obs in bunching sample (ok_b): " r(N)

*----------------------------
* 2) Saez-style excess mass program (deg=3 fixed)
*----------------------------
capture program drop saez_excess
program define saez_excess, rclass
    syntax, SPEC(string) BW(real) WL(real) WU(real) FITL(real) FITU(real)

    preserve
    keep if ok_b
    keep r_dir

    * bin centers
    gen double bin    = floor(r_dir/`bw')*`bw'
    gen double center = bin + `bw'/2
    drop bin

    * bin counts
    collapse (count) n=r_dir, by(center)

    * window
    gen byte inwin = inrange(center, `wl', `wu')

    * fit range restriction (after collapse)
    keep if inrange(center, `fitl', `fitu')

    * polynomial terms (deg=3)
    gen double c1 = center
    gen double c2 = center^2
    gen double c3 = center^3

    reg n c1 c2 c3 if !inwin
    predict double n_hat, xb

    count if inwin
    local bins = r(N)

    summ n if inwin
    local actual = r(sum)

    summ n_hat if inwin
    local counter = r(sum)

    gen double excess = n - n_hat if inwin
    summ excess if inwin
    local ex = r(sum)

    return local spec "`spec'"
    return scalar bw = `bw'
    return scalar wl = `wl'
    return scalar wu = `wu'
    return scalar fitl = `fitl'
    return scalar fitu = `fitu'
    return scalar bins = `bins'
    return scalar actual = `actual'
    return scalar counter = `counter'
    return scalar ex = `ex'
    return scalar rel_ex = `ex'/`counter'
    return scalar ex_share = `ex'/`actual'

    restore
end

*----------------------------
* 3) Run A (base), B and C (robustness)
*----------------------------
tempname posth
tempfile results
postfile `posth' str10 spec double bw wl wu fitl fitu bins actual counter ex rel_ex ex_share using `results', replace

* common fit range
local fitl = 0.8
local fitu = 1.2

* --- A (base) ---
saez_excess, spec("A_base") bw(0.005) wl(0.98) wu(1.02) fitl(`fitl') fitu(`fitu')
return list
post `posth' ("A_base") (r(bw)) (r(wl)) (r(wu)) (r(fitl)) (r(fitu)) (r(bins)) ///
              (r(actual)) (r(counter)) (r(ex)) (r(rel_ex)) (r(ex_share))

di as txt "---- A (base) ----"
di as txt "bins in window: " %9.0f r(bins)
di as txt "Actual mass: " %12.4f r(actual)
di as txt "Counterfactual mass: " %12.4f r(counter)
di as txt "Excess mass: " %12.4f r(ex)
di as txt "Excess/Counterfactual: " %9.4f r(rel_ex)
di as txt "Excess/Actual: " %9.4f r(ex_share)

* --- B (robustness: finer bins) ---
saez_excess, spec("B_bw0p002") bw(0.002) wl(0.98) wu(1.02) fitl(`fitl') fitu(`fitu')
return list
post `posth' ("B_bw0p002") (r(bw)) (r(wl)) (r(wu)) (r(fitl)) (r(fitu)) (r(bins)) ///
              (r(actual)) (r(counter)) (r(ex)) (r(rel_ex)) (r(ex_share))

di as txt "---- B (robustness) ----"
di as txt "bins in window: " %9.0f r(bins)
di as txt "Actual mass: " %12.4f r(actual)
di as txt "Counterfactual mass: " %12.4f r(counter)
di as txt "Excess mass: " %12.4f r(ex)
di as txt "Excess/Counterfactual: " %9.4f r(rel_ex)
di as txt "Excess/Actual: " %9.4f r(ex_share)

* --- C (robustness: wider window) ---
saez_excess, spec("C_win0p97_1p03") bw(0.005) wl(0.97) wu(1.03) fitl(`fitl') fitu(`fitu')
return list
post `posth' ("C_win0p97_1p03") (r(bw)) (r(wl)) (r(wu)) (r(fitl)) (r(fitu)) (r(bins)) ///
              (r(actual)) (r(counter)) (r(ex)) (r(rel_ex)) (r(ex_share))

di as txt "---- C (robustness) ----"
di as txt "bins in window: " %9.0f r(bins)
di as txt "Actual mass: " %12.4f r(actual)
di as txt "Counterfactual mass: " %12.4f r(counter)
di as txt "Excess mass: " %12.4f r(ex)
di as txt "Excess/Counterfactual: " %9.4f r(rel_ex)
di as txt "Excess/Actual: " %9.4f r(ex_share)

postclose `posth'

*----------------------------
* 4) Save results
*----------------------------
use `results', clear
save "saez_bunching_results_ABC.dta", replace
export delimited using "saez_bunching_results_ABC.csv", replace

di as txt "Saved: saez_bunching_results_ABC.dta / .csv"