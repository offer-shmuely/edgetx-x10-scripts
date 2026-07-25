local fields_presets = {
    { text="None (Clear All)",            fields={1, 1, 1, 1}                  },
    { text="First 4 (Reset to default)",  fields={2, 3, 4, 5}                  },
    { text="ELRS Link quality",           fields={"RQly","TPWR","RSNR","---"}  },
    { text="ELRS Antenna selection",      fields={"RQly","1RSS","2RSS","ANT"}  },
    { text="Rotorflight Power",           fields={"Vcel","Curr","Capa","Hspd"} },
    { text="Rotorflight Headspeed",       fields={"Hspd","Thr","Alt","SA"}     },
    { text="Rotorflight GOV",             fields={"Hspd","GOV","PID#","---"}   },
    { text="Rotorflight ESC",             fields={"Hspd","Curr","Capa","EscT"} },
}

return fields_presets
