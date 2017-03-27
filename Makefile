EXE = PEFILE.exe              #ָ������ļ�
OBJS = PEFILE.obj		#��Ҫ��Ŀ���ļ�
RES = PEFILE.res

#LINK_FLAG = /subsystem:windows /base:0x500000 /libpath:"D:\masm32\lib"	/section:.text,RWE #����ѡ��
LINK_FLAG = /subsystem:windows /libpath:"D:\masm32\lib"	/section:.text,RWE #����ѡ��
ML_FLAG = /c /coff /I"D:\masm32\include"	#����ѡ��
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
