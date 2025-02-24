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

'set vpage 0 11 0 8.5'
'set parea 1.2 10.2 1.2 7.9'

'set xlab on'
'set ylab on'
'set xlint 0'
'set ylint 0'
'set xlopts 1 4 0.2'
'set ylopts 1 4 0.2'

'set clab on'
'set clopts 1 4 0.15'

'set rgb 70 11 41 150' 
'fshade 0 20 15 maisfresco'
'set clevs <CINT>'
'set ccols <CCOL>'


'set gxout grfill'
'd <VAR>'

'cbarn * 1.2'   
'draw title Tempo Car. SPI<TITLE>'

'set string 1 l 5'
'draw string '0.5' '0.2' <BOTTOM>' 

'gxprint <NOME_FIG>.png'
'quit'
