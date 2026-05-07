xrun: 
	cd ./sim; xrun ../tb/tb.sv ../rtl/im2col.sv -access +rwc -gui
run:
	cd ./sim; xrun ../tb/tb.sv ../rtl/im2col.sv

clean:
	rm -rf csrc simv simv.daidir ucli.key
	cd ./sim/;rm -rf * rm -rf .*
