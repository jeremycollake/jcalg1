rem make static library(s)
rem requires masm 6.15+
del jcalg1_d.obj
del jcalg1_d_fast.obj
del jcalg1_c.obj
del jcalg1_getinfo.obj
del jcalg1.obj
ml /c /W0 /DConditionalEnd=END jcalg1_d.asm /omf 
ml /c /W0 /DConditionalEnd=END jcalg1_d_fast.asm /omf
ml /c /W0 /DConditionalEnd=END jcalg1_c.asm /omf 
ml /c /W0 /DGETINFO_OBJ=END jcalg1_getinfo.asm /omf 
del jcalg1_static.lib
lib jcalg1_d.obj jcalg1_d_fast.obj jcalg1_c.obj jcalg1_getinfo.obj /OUT:jcalg1_static.lib
rem Make the DLL
Ml.exe /c /W0 /coff jcalg1.asm
link /FILEALIGN:512 /DLL /SUBSYSTEM:WINDOWS /DEF:JCALG1.DEF /IMPLIB:jcalg1_import.lib JCALG1.OBJ 
del jcalg1.obj
implib jcalg1_import_omf.lib jcalg1.dll