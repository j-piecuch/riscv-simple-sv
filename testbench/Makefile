all: run

%:
	make -k -C singlecycle $*
	make -k -C multicycle $*
	make -k -C pipeline $*
	make -k -C pipeline_with_forwarding $*


