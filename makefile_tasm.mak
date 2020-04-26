NAME = jcalg1
OBJS = $(NAME).obj 
DEF  = $(NAME).def

IMPORT=

$(NAME).EXE: $(OBJS) $(DEF)  
  tlink32 /Tpd /V4.0  /aa /c /m /ml /x $(OBJS),$(NAME),, $(IMPORT), $(DEF)

.asm.obj:  
  tasm32 /ml /m /zn /w0 /dTASM $&.asm
