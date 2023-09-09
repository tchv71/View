M80PATH=D:/M80
PORT=COM2
OBJS= VFILE.REL VDISP.REL VEND.REL
.SUFFIXES: .ASM .REL .BIN

.ASM.REL:
	M80 '=$< /I/L'

clean:
	del $(OBJS)
	del *.PRN
	del *.rkl
	del *.COM

all: View.rkl Makefile

View.COM: $(OBJS)
	$(M80PATH)/L80 VFILE,VDISP,MYLIB/S,VEND,$@/Y/N/E/U

send: View.rkl
	MODE $(PORT): baud=115200 parity=N data=8 stop=1
	cmd /C copy /B  $< $(PORT)

View.rkl: View.COM
	../makerk/Release/makerk.exe 100 $< $@
