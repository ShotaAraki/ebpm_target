/********************************************************************
99_paths.do
- Detect external drive letter by searching for a marker folder.
- Define project paths as globals.
********************************************************************/

* --- project root on PC (edit once) ---
global PROJ "C:\Users\shota\ebpm_target"

* --- marker folder on external HDD (must exist) ---
local marker "/ebpm_target_root"

* --- search drive letters ---
global EXTDRIVE ""
foreach L in D E F G H I J K L M N O P Q R S T U V W X Y Z {
    capture confirm file "`L':`marker'\_marker.txt"
    if !_rc {
        global EXTDRIVE "`L:'"
        continue, break
    }
    * もし_marker.txtを作らない運用なら、フォルダ存在で判定：
    capture confirm dir "`L':`marker'"
    if !_rc {
        global EXTDRIVE "`L'"
        continue, break
    }
}

if "$EXTDRIVE"=="" {
    di as error "External drive not found. Expected marker folder: `marker'"
    di as error "Please connect HDD and ensure `marker' exists."
    exit 198
}

* --- data folders on external HDD ---
global DATA_ROOT "$EXTDRIVE:/ebpm_target_root"
global DATA_RAW  "$DATA_ROOT/rawdata"
global DATA_WORK "$DATA_ROOT/dtas"

* --- output folders inside repo (Git-managed) ---
global DOFILE "$PROJ/dofiles"
global FIG    "$PROJ/figure"
global TAB    "$PROJ/table"
global LOG    "$PROJ/log"
global TEX    "$PROJ/latex"

* optional: show paths
di as txt "PROJ      = $PROJ"
di as txt "DATA_ROOT = $DATA_ROOT"
di as txt "DATA_RAW  = $DATA_RAW"
di as txt "DATA_WORK = $DATA_WORK"