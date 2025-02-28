'set display color white'
'set rgb 99 255 255 255'
'c'

'open <CTL>'

'set lat <LATI> <LATF>'
'set lon <LONI> <LONF>'
'set mpdset mres brmap'

'set grads off'
'set grid off'
'set mpdraw on'
'set mproj latlon'
'set map 1 1 7'        

'set xlab on'
'set ylab on'
'set xlint 0'
'set ylint 0'
'set xlopts 1 4 0.2'
'set ylopts 1 4 0.2'

'set clab on'
'set clopts 1 4 0.15'

'set clevs <CINT>'

'set gxout grfill'
'd <VAR>'

'cbarn * 1.2'   
'draw title Tempo Car. SPI<TITLE>'

'set string 1 c 5'
'draw string '4.0' '0.2' <BOTTOM>' 

'gxprint <NOME_FIG>.png'
'quit'
