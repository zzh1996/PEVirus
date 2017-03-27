ml /c /coff /I"C:\masm32\include" PEFILE.asm
rc /i"C:\masm32\include" PEFILE.rc
link /subsystem:windows /libpath:"C:\masm32\lib" /section:.text,RWE /out:PEFILE.exe PEFILE.obj PEFILE.res
pause