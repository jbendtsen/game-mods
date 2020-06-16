# this code gets hooked at 0x8030fca8
# by default it gets placed at 0x80002c00, therefore the jump instruction is 0x4BCF2F58

fly:

# check to see if r31 is the player's car

	lis r24,0x8067        # player = 0x80673ef0
	ori r24,r24,0x3ef0
	cmpw cr0,r24,r31      # if r31 != player:
	bne+ exit             #   goto end

	lis r24,0x817f
	ori r24,r24,0xfe00    # r24 = 0x817ffe00 = the pointer to our memory store

# back up some floating-point registers and other stuff (doesn't look like the fixed-point regs need backing up)

	stfs f0,0x0050(r24)
	stfs f1,0x0054(r24)
	# no need to back up f2
	stfs f3,0x005c(r24)
	stfs f4,0x0060(r24)
	stfs f5,0x0064(r24)
	stfs f6,0x0068(r24)
	stfs f7,0x006c(r24)
	stfs f8,0x0070(r24)
	stfs f9,0x0074(r24)
	stfs f10,0x0078(r24)
	stfs f11,0x007c(r24)

	# naive way of backing up the weight variable
	lwz r4,0x002c(r31)
	cmpwi r4,0
	beq+ 8
	stw r4,0x003c(r24)

# determine whether the player has just activated / deactivated flying mode

	lis r4,0x8072         # get GC controller bits for player 1
	lwz r4,0x2B40(r4)
	stw r4,0x0020(r24)

	# get the number of frames the Z button has been held for
	lis r5,0x0010         # Z button status uses bit 20 (0x0010_0000) according to YAGCD
	li r6,0x0030          # 0x0038 is a relative pointer (using r24) which gives us a place to store our frame counter
	and. r5,r4,r5
	beq+ 16
	lwzx r3,r24,r6
	addi r3,r3,1
	b 8
	li r3,0
	stwx r3,r24,r6

	lwz r7,0x0034(r24)    # get is_active
	cmpwi cr0,r3,1
	bne+ 52               # if n_frames for Z == 1, then the Z button was just pressed
	xori r7,r7,1          # in which case we invert the is_active variable
	andi. r7,r7,1         # and either enable or disable wall collision and respawning
	beq 20
	lis r5,0x4e80         # disable collision
	ori r5,r5,0x0020
	mr r6,r5
	b 20
	lis r5,0x9421         # enable collision
	ori r5,r5,0xfc20
	lis r6,0x9421
	ori r6,r6,0xfea0
	bl sync_pokes

	andi. r7,r7,1         # update is_active
	stw r7,0x0034(r24)
	bne- 24               # if !is_active:
	lwz r6,0x003c(r24)    #   load the original weight value
	stw r6,0x002c(r31)    #   store it back to the address for the player's weight
	lwz r6,0x0044(r24)    #   load min_flying_speed
	stw r6,0x0040(r24)    #   flying_speed = min_flying_speed
	b exit                #   goto exit

# get control stick values

	lbz r5,0x0022(r24)
	bl get_stick_value
	stw r3,0x0000(r24)    # r3 contains the x stick value in floating-point

	lbz r5,0x0023(r24)
	bl get_stick_value
	stw r3,0x0004(r24)

# get car facing direction

	lis r4,0x3f80         # more floating point literals
	stw r4,0x0008(r24)    # store 1
	lis r4,0xbf80
	stw r4,0x000c(r24)    # store -1
	lis r4,0x4000
	stw r4,0x0010(r24)    # store 2
	li r4,0
	stw r4,0x0014(r24)    # store 0

	# some named constants
	lis r4,0x4020         # const pitch_vel_factor = 2.5
	stw r4,0x0024(r24)
	lis r4,0x3fc0         # const yaw_speed = 1.5
	stw r4,0x0028(r24)
	lis r4,0x4140         # const min_flying_speed = 12
	stw r4,0x0044(r24)

	lfs f0,0x0000(r31)    # get the car's angle values
	lfs f1,0x0004(r31)    # note: these are stored in square-root form
	lfs f2,0x0008(r31)
	lfs f3,0x000c(r31)

	lfs f7,0x0008(r24)    # load 1
	lfs f8,0x000c(r24)    # load -1
	fmuls f10,f1,f3       # xz_sign = angle_1 * angle_3
	fmuls f9,f0,f3        # y_sign = angle_0 * angle_3
	fsel f10,f10,f7,f8    # xz_sign = xz_sign >= 0.0 ? 1 : -1
	fsel f9,f9,f8,f7      # y_sign = y_sign >= 0.0 ? -1 : 1 (inverted)

	fabs f0,f0
	fabs f2,f2
	fadds f7,f0,f2        # y_delta = |angle_0| + |angle_2|

	fmuls f1,f1,f1        # square the angle values
	fmuls f3,f3,f3

	fadds f8,f1,f3        # xz_diameter = sq_ang_1 + sq_ang_3
	fmuls f5,f7,f9        # y_coeff = y_delta * y_sign

	# z_coeff = -1 * (2 * (sq_ang_1 / xz_diameter) - 1)
	lfs f11,0x0010(r24)   # f11 = 2
	fdivs f4,f1,f8        # sq_ang_1 / xz_diameter
	fmuls f4,f4,f11
	lfs f11,0x000c(r24)   # f11 = -1
	fadds f4,f4,f11
	fmuls f4,f4,f11

	# x_coeff = xz_sign * sqrt(1 - (x_vel^2))
	lfs f11,0x0008(r24)   # f11 = 1
	fmuls f6,f4,f4
	fsubs f6,f11,f6
	fabs f6,f6            # absolute-ify f6 for safety
	lfs f11,0x0014(r24)   # f11 = 0
	fcmpu cr0,f6,f11
	beq- 12               # if f6 != 0:
	frsqrte f6,f6         #   f6 = 1 / sqrt(f6)
	fres f6,f6            #   f6 = 1 / f6 (I don't think the Gekko supports fsqrts)
	fmuls f6,f6,f10

# update flying speed

	# get the held state of the R button
	lwz r4,0x0020(r24)
	andis. r3,r4,0x0020   # R button flag = bit 21 or 0x0020_0000
	beq+ 12               # if R_btn_held:
	lis r3,0x3ef0         #   accel = 0.46875
	b 8                   # else:
	lis r3,0xbef0         #   accel = -0.46875
	stw r3,0x004c(r24)    # store accel

	lfs f1,0x004c(r24)    # load accel into an FPR
	andis. r3,r4,0x0040
	beq+ 24               # if L_btn_held:
	lfs f11,0x0010(r24)   #   accel *= 2.0
	fmuls f1,f1,f11
	lis r3,0x43b9         #   max_flying_speed = 371.5
	ori r3,r3,0xc000
	b 12                  # else:
	lis r3,0x42e9         #   max_flying_speed = 116.75
	ori r3,r3,0x8000
	stw r3,0x0048(r24)    # store max_flying_speed

	lfs f0,0x0040(r24)    # load flying_speed
	fadds f0,f0,f1        # flying_speed += accel

	lfs f2,0x0044(r24)
	fsubs f1,f0,f2        # delta = flying_speed - min_flying_speed
	fsel f0,f1,f0,f2      # flying_speed = delta >= 0.0 ? flying_speed : min_flying_speed

	lfs f3,0x0048(r24)
	fsubs f1,f0,f3        # delta = flying_speed - max_flying_speed
	fsel f0,f1,f3,f0      # flying_speed = delta >= 0.0 ? max_flying_speed : flying_speed

	stfs f0,0x0040(r24)   # save flying_speed

# modfiy the car's physics variables

	li r3,0
	stw r3,0x002c(r31)    # car.weight = 0

	fmuls f4,f4,f0        # x_vel = x_coeff * flying_speed
	fmuls f5,f5,f0        # y_vel = y_coeff * flying_speed
	fmuls f6,f6,f0        # z_vel = z_coeff * flying_speed
	fmuls f4,f4,f8        # x_vel *= xz_diameter
	fmuls f6,f6,f8        # z_vel *= xz_diameter
	stfs f6,0x0020(r31)   # car.x_vel = x_vel
	stfs f5,0x0024(r31)   # car.y_vel = y_vel
	stfs f4,0x0028(r31)   # car.z_vel = z_vel

	lfs f10,0x0000(r24)   # get stick_x
	lfs f2,0x0028(r24)    # get yaw_speed
	fmuls f2,f10,f2       # yaw_vel = stick_x * yaw_speed
	lfs f10,0x0024(r24)   # load pitch_vel_factor
	fres f11,f0           # pitch_speed = pitch_vel_factor / flying_speed
	lfs f10,0x0004(r24)   # get stick_y
	fmuls f1,f10,f4       # pitch_coeff = stick_y * z_coeff
	fmuls f3,f10,f6       # roll_coeff = stick_y * x_coeff
	fneg f3,f3
	fmuls f1,f1,f11
	fmuls f3,f3,f11
	stfs f1,0x0030(r31)   # car.pitch_vel = pitch_coeff * pitch_speed
	stfs f2,0x0034(r31)   # car.yaw_vel = yaw_vel
	stfs f3,0x0038(r31)   # car.roll_vel = roll_coeff * pitch_speed

# cleanup

	lfs f0,0x0050(r24)
	lfs f1,0x0054(r24)
	lfs f3,0x005c(r24)
	lfs f4,0x0060(r24)
	lfs f5,0x0064(r24)
	lfs f6,0x0068(r24)
	lfs f7,0x006c(r24)
	lfs f8,0x0070(r24)
	lfs f9,0x0074(r24)
	lfs f10,0x0078(r24)
	lfs f11,0x007c(r24)
exit:
	lfs f2,0x0020(r31)    # original instruction
	lis r24,0x8030
	ori r24,r24,0xfcac
	mtctr r24
	bctr

get_stick_value:

# apply deadzone

	andi. r6,r5,0x80      # get the highest bit of pos
	beq- 12               # if set:
	andi. r5,r5,0x7f      #   pos = pos & 0x7f
	b 12                  # else:
	li r3,0x80
	sub r5,r3,r5          #   pos = 0x80 - pos

	subic. r3,r5,0x14
	bge- 12               # if pos < 20:
	li r3,0
	blr                   #   return 0

# convert result to float (doesn't look like there's a Gekko instruction for it)

	xori r6,r6,0x80       # invert the highest bit of pos, such that it represents the negative flag
	slwi r6,r6,24         # take the negative flag up to the 31st bit

	andi. r5,r5,0x7f      # clear the negative flag
	cntlzw r4,r5          # get leading zeroes

	li r3,150             # get the exponent. note that we take off 7 so that the end result is a 128th of its initial value.
	sub r3,r3,r4          # exponent = (31 - lead_zeroes) + 127 - (7 - 1) = 150 - lead_zeroes
	slwi r3,r3,23         # place it next to the sign bit

	subi r4,r4,8          # modify leading zeroes
	rlwnm r5,r5,r4,0,23   # shift mantissa into position

	add r3,r6,r3          # return sign + exponent + mantissa
	add r3,r3,r5

	blr

sync_pokes:
	lis r3,0x802f         # form the address 0x802ecb6c (the start of the respawn function)
	stw r5,-0x3494(r3)    # write r5, which will either be the original instruction or "blr"
	dcbf 0,r3             # flush data cache
	icbi 0,r3             # flush instruction cache

	lis r4,0x8031         # form the address 0x803153dc (the start of the wall collision function)
	stw r6,0x53dc(r4)
	dcbf 0,r4
	icbi 0,r4

	sync                  # wait for data cache -> RAM
	isync                 # wait for instruction cache -> RAM
	blr
