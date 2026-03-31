cap log close
log using "$PROJ\log\fig_A1_rdir",replace

version 17

clear all

set more off

/*---
    
- Figure A1: Distribution of direction-adjusted achievement ratio (r_dir)
- Consistent with:
- 
    - cr_[[dta.do](http://dta.do)]: produces kpi_tidy_for_bunching.dta
- 
    - saez_[[260328.do](http://260328.do)]: defines target_dir/actual_dir, r_dir, ok_b
- 
- Outputs (fixed file names):
- 
    - figure/fig_A1_all_bw001.png     (0–3, bin=0.01)
- 
    - figure/fig_A1_zoom_bw0005.png   (0.8–1.2, bin=0.005)
- 
    - figure/fig_A1_zoom_bw0002.png   (0.8–1.2, bin=0.002)
- 
    
    ---*/
    

cap mkdir "figure"

* 1) Load tidy data

use "$DATA_WORK\kpi_tidy_for_bunching.dta", clear



* 2) Plot settings

set scheme s2color

* 3) Figure A1(a): full range 0–3, bin=0.01

histogram r_dir if ok_b, ///
width(0.01) start(0) ///
xscale(range(0 3)) ///
xline(1, lcolor(red) lwidth(medthick)) ///
xtitle("Achievement rate (direction-adjusted) r_dir") ///
ytitle("Count") ///
title("Figure A1(a): Distribution of r_dir (0–3), bin=0.01") ///
note("Sample: ok_b==1 (target_dir>0, actual_dir>=0, 0<r_dir<=3); N=`N_okb'") ///
graphregion(color(white))

graph export "$PROJ\figure/fig_A1_all_bw001.png", replace width(2400)

* 4) Figure A1(b): zoom 0.8–1.2, bin=0.005

histogram r_dir if ok_b & inrange(r_dir, 0.8, 1.2), ///
width(0.005) start(0.8) ///
xscale(range(0.8 1.2)) ///
xline(1, lcolor(red) lwidth(medthick)) ///
xtitle("r_dir") ///
ytitle("Count") ///
title("Figure A1(b): Zoom-in around 1.0 (0.8–1.2), bin=0.005") ///
note("Underlying sample: ok_b==1; N(ok_b)=`N_okb'") ///
graphregion(color(white))

graph export "$PROJ\figure/fig_A1_zoom_bw0005.png", replace width(2400)

* 5) Figure A1(c): zoom 0.8–1.2, bin=0.002

histogram r_dir if ok_b & inrange(r_dir, 0.8, 1.2), ///
width(0.002) start(0.8) ///
xscale(range(0.8 1.2)) ///
xline(1, lcolor(red) lwidth(medthick)) ///
xtitle("r_dir") ///
ytitle("Count") ///
title("Figure A1(c): Zoom-in around 1.0 (0.8–1.2), bin=0.002") ///
note("Underlying sample: ok_b==1; N(ok_b)=`N_okb'") ///
graphregion(color(white))

graph export "$PROJ\figure/fig_A1_zoom_bw0002.png", replace width(2400)

di as txt "Done: figure/fig_A1_*.png"