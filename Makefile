

GCCVERSION := 4.3.6
GCCVERSION := 4.0.3
ifeq ($(GCCVERSION),4.0.3) 
    define B
	"Target is 4.0.3, old gcc"
    endef
else
    define B
	"Target is not 4.0.3, new gcc"
    endef
endif
all:
	echo $B
	@-false
	@-rm shit3399
	echo all done


