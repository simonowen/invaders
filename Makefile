NAME=invaders
DEPS=invaders.rom

.PHONY: clean

$(NAME).dsk: $(NAME).asm $(DEPS)
	pyz80.py -I samdos2 --exportfile=$(NAME).sym $(NAME).asm

run: $(NAME).dsk
	open $(NAME).dsk

clean:
	rm -f $(NAME).dsk $(NAME).sym
