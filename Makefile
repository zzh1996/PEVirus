EXE = PEFILE.exe              #指定输出文件
OBJS = PEFILE.obj		#需要的目标文件
RES = PEFILE.res

#LINK_FLAG = /subsystem:windows /base:0x500000 /libpath:"D:\masm32\lib"	/section:.text,RWE #连接选项
LINK_FLAG = /subsystem:windows /libpath:"D:\masm32\lib"	/section:.text,RWE #连接选项
ML_FLAG = /c /coff /I"D:\masm32\include"	#编译选项
RC_FLAG = /i"D:\masm32\include"

$(EXE): $(OBJS) $(RES)
	Link $(LINK_FLAG) /out:$(EXE) $(OBJS) $(RES)

.asm.obj:
	ml $(ML_FLAG) $<
.rc.res:
	rc $(RC_FLAG) $<
clean:
	del *.obj
	del *.res
