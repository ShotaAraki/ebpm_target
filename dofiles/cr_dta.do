cap log close
log using "C:\Users\shota\Downloads\cr_dta",replace
****************************************************
* 0) read
****************************************************
clear all
set more off

import delimited using "C:\Users\shota\Downloads\3-1_RS_2025_効果発現経路_目標・実績\3-1_RS_2025_効果発現経路_目標・実績.csv", varnames(1) encoding(utf8) clear

* 重要：この列で「1.目標年度 / 2.目標値 / 3.実績値 / 4.達成率」を区別
* 例では「目標年度／目標値／実績値／達成率」という列に入っている想定
rename 目標年度目標値実績値達成率 rowtype



*----------------------------
* 1) Configure column names (edit here only if needed)
*----------------------------
local rowtype   "rowtype"
local id_biz    "予算事業id"
local num       "アクティビティアウトプットアウトカムの番号"
local kind      "種別アクティビティアウトプットアウトカム"
local period    "アウトカムの期間"
local qtype     "成果目標の種類"
local goaltext  "アクティビティ活動目標成果目標"
local kpiname   "活動指標成果指標"
local unit      "単位"
local trend     "改善の上向き下向き"

* year columns: v29(=2007) ... v82(=2060)
local stub      "v"
local vstart    29
local vend      82

*----------------------------
* 2) Keep only needed rows and quantitative KPIs
*----------------------------
keep if inlist(`rowtype', "2.目標値", "3.実績値", "4.達成率")

* 定量的に限定（まずはバンチング検出に必要）
keep if `qtype' == "定量的"

* KPI名や単位が "-" や欠損のものは落とす（定性的混入対策）
drop if missing(`kpiname') | `kpiname'=="-"
drop if missing(`unit')   | `unit'=="-"

* テキストの揺れを少しでも減らす（全角スペース等の事故を軽減）
foreach x in `period' `goaltext' `kpiname' `unit' `trend' `kind' {
    capture confirm string variable `x'
    if !_rc {
        replace `x' = ustrtrim(`x')
    }
}

*----------------------------
* 3) Build the minimal "series id"
*   - このデータでは、同一KPI名・単位でも短期/長期、目標文言で別系列があり得る
*   - ただしキーに長文をそのまま入れると重いので、goaltextはhash化して短いIDにする
*----------------------------
egen long goalhash = group(`goaltext'), label
local serieskey `id_biz' `num' `kind' `period' `kpiname' `unit' goalhash

* series key（最小限で、実例169/170の短期/長期・87/100の併存を識別できる形）
*  - 予算事業id
*  - 番号（1,3,201等）
*  - 種別（アウトカム/アウトプット等）
*  - 期間（短期/長期等）  ←短期/長期の分離に必須
*  - KPI名
*  - 単位
*  - 目標文言hash          ←同一KPI名・同一単位で別目標を分離する保険
*
* ※ trend（上がると良い等）は空欄が多い場合があるので、まずキーに入れない（必要なら後で追加）
local serieskey `id_biz' `num' `kind' `period' `kpiname' `unit' goalhash

*----------------------------
* 4) Drop exact duplicate rows within each rowtype & serieskey
*   - ここで残る重複は「同じ系列・同じrowtypeが複数行ある」=データ重複の可能性が高い
*   - 安全策として完全一致は落とす（wide列も含めて）
*----------------------------
duplicates drop `rowtype' `serieskey', force

*----------------------------
* 5) Reshape to long over years v29-v82
*----------------------------
* v29-v82 が存在するかチェック
capture confirm variable `stub'`vstart'
if _rc {
    di as error "Cannot find year columns like `stub'`vstart'. Check variable names with: describe"
    exit 198
}

reshape long `stub', i(`rowtype' `serieskey') j(vindex)

* vindex -> calendar year (v29=2007)
gen year = vindex + 1978
drop vindex
rename `stub' value

* 欠損は落とす
drop if missing(value)

*----------------------------
* 6) Convert rowtype to target/actual/ach columns
*----------------------------
gen rt = ""
replace rt = "target" if `rowtype'=="2.目標値"
replace rt = "actual" if `rowtype'=="3.実績値"
replace rt = "ach"    if `rowtype'=="4.達成率"

drop `rowtype'
drop if rt==""

* strL 対策：KPI名をID化
egen long kpi_id = group(`kpiname'), label
label var kpi_id "group id for KPI name"

* ついでに unit や period も怪しければID化してよい（任意）
* egen long unit_id = group(`unit'), label
* egen long period_id = group(`period'), label

* serieskey を作り直す（kpiname を外して kpi_id を入れる）
local serieskey `id_biz' `num' `kind' `period' `unit' goalhash kpi_id
di "`serieskey'"
di as txt "i() will be: `serieskey' year"


reshape wide value, i(`serieskey' year) j(rt) string
rename valuetarget target
rename valueactual actual
rename valueach    ach

*----------------------------
* 7) Create achievement ratio r (preferred) and r2 (from actual/target)
*----------------------------
* 達成率(ach)が%表記（100=100%）の想定
gen r  = ach/100 if !missing(ach)
gen r2 = actual/target if target>0 & !missing(actual) & !missing(target)

* 可能なら r を優先、欠損は r2 で埋める（達成率列が空のケース対策）
gen r_use = r
replace r_use = r2 if missing(r_use) & !missing(r2)

label var r_use "achievement ratio (1=100%)"

*----------------------------
* 8) Final checks
*----------------------------
summ r r2 r_use, detail
corr r r2 if !missing(r) & !missing(r2)

* 100%近傍の粗いチェック
count if abs(r_use-1)<0.0001
di "exactly 1.0000 (within 1e-4): " r(N)

*----------------------------
* 9) Save tidy file for bunching plots
*----------------------------
save "kpi_tidy_for_bunching.dta", replace
export delimited using "kpi_tidy_for_bunching.csv", replace
