%num = type double
%v4 = type <4 x %num>

declare %num @llvm.sqrt.f64(%num)

define %v4 @sool_v4_add(%v4 %a, %v4 %b)
{
	%1 = fadd %v4 %a, %b
	ret %v4 %1
}

define %v4 @sool_v4_sub(%v4 %a, %v4 %b)
{
	%1 = fsub %v4 %a, %b
	ret %v4 %1
}

define %v4 @sool_v4_nmul(%v4 %a, %num %b)
{
	%1 = insertelement <1 x %num> zeroinitializer, %num %b, i32 0
	%2 = shufflevector <1 x %num> %1, <1 x %num> undef, <4 x i32> zeroinitializer
	%3 = fmul %v4 %a, %2
	ret %v4 %3
}

define %v4 @sool_v4_ndiv(%v4 %a, %num %b)
{
	%1 = insertelement <1 x %num> zeroinitializer, %num %b, i32 0
	%2 = shufflevector <1 x %num> %1, <1 x %num> undef, <4 x i32> zeroinitializer
	%3 = fdiv %v4 %a, %2
	ret %v4 %3
}

define %num @sool_v4_dot(%v4 %a, %v4 %b)
{
	%1 = fmul %v4 %a, %b
	%x = extractelement %v4 %1, i32 0
	%y = extractelement %v4 %1, i32 1
	%z = extractelement %v4 %1, i32 2
	%k = extractelement %v4 %1, i32 3
	%2 = fadd %num %x, %y
	%3 = fadd %num %2, %z
	%4 = fadd %num %3, %k
	ret %num %4
}

define %v4 @sool_v4_cross(%v4 %a, %v4 %b)
{
	%a120 = shufflevector %v4 %a, %v4 undef, <3 x i32> <i32 1, i32 2, i32 0>
	%b120 = shufflevector %v4 %b, %v4 undef, <3 x i32> <i32 1, i32 2, i32 0>
	%a201 = shufflevector %v4 %a, %v4 undef, <3 x i32> <i32 2, i32 0, i32 1>
	%b201 = shufflevector %v4 %b, %v4 undef, <3 x i32> <i32 2, i32 0, i32 1>
	
	%1 = fmul <3 x %num> %a120, %b201
	%2 = fmul <3 x %num> %a201, %b120
	%3 = fsub <3 x %num> %1, %2
	
	%4 = shufflevector <3 x %num> %3, <3 x %num> undef, <4 x i32> <i32 0, i32 1, i32 2, i32 undef>
	
	ret %v4 %4
}

define %num @sool_v4_sqlen(%v4 %a)
{
	%1 = tail call %num @sool_v4_dot(%v4 %a, %v4 %a)
	ret %num %1
}

define %num @sool_v4_len(%v4 %a)
{
	%1 = tail call %num @sool_v4_sqlen(%v4 %a)
	%2 = tail call %num @llvm.sqrt.f64(%num %1)
	ret %num %2
}
