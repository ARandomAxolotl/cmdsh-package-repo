for /f "usebackq tokens=1,* delims== eol=#" %%A in ("%~1") do (
    set "key=%%A"
    set "val=%%B"
    for /f "tokens=* delims= " %%K in ("!key!") do set "key=%%K"
    if defined val (
        for /f "tokens=* delims= " %%V in ("!val!") do set "val=%%V"
    )
    if defined key (
        set "config_!key!=!val!"
    )
)