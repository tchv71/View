M80PATH=D:/M80
PORT=COM5
OBJS= VFILE.REL VDISP.REL VEND.REL
ASMS= VFILE.ASM VDISP.ASM VEND.ASM
.SUFFIXES: .ASM .REL .BIN

#.ASM.REL:
#	M80 '=$< /I/L'

clean:
	del view.rel
	del *.PRN
	del *.rkl
	del *.COM

all: View.rkl Makefile

View.REL: View.ASM $(ASMS)
	$(M80PATH)/M80 =$</I/L
	../m80noi/x64/Release/m80noi.exe VIEW.PRN

View.COM: VIEW.REL
	$(M80PATH)/L80 /P:103/D:900,VIEW,MYLIB/S,$@/Y/N/E/U

send: View.rkl
	MODE $(PORT): baud=115200 parity=N data=8 stop=1
	cmd /C copy /B  $< $(PORT)

View.rkl: View.COM
	../makerk/Release/makerk.exe 100 $< $@
