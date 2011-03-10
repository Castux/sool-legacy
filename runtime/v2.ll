%num = type double
%v2 = type <2 x %num>

declare double @llvm.sqrt.f64(double)
declare double @llvm.cos.f64(double)
declare double @llvm.sin.f64(double)

declare double @atan2(double, double)
declare double @abs(double)


define %v2 @sool_v2_add(%v2 %a, %v2 %b)
{
	%1 = fadd %v2 %a, %b
	ret %v2 %1
}

define %v2 @sool_v2_sub(%v2 %a, %v2 %b)
{
	%1 = fsub %v2 %a, %b
	ret %v2 %1
}

define %v2 @sool_v2_nmul(%v2 %a, %num %b)
{
	%1 = insertelement <1 x %num> zeroinitializer, %num %b, i32 0
	%2 = shufflevector <1 x %num> %1, <1 x %num> undef, <2 x i32> zeroinitializer
	%3 = fmul %v2 %a, %2
	ret %v2 %3
}

define %v2 @sool_v2_ndiv(%v2 %a, %num %b)
{
	%1 = insertelement <1 x %num> zeroinitializer, %num %b, i32 0
	%2 = shufflevector <1 x %num> %1, <1 x %num> undef, <2 x i32> zeroinitializer
	%3 = fdiv %v2 %a, %2
	ret %v2 %3
}

define %num @sool_v2_dot(%v2 %a, %v2 %b)
{
	%1 = fmul %v2 %a, %b
	%x = extractelement %v2 %1, i32 0
	%y = extractelement %v2 %1, i32 1
	%2 = fadd %num %x, %y
	ret %num %2
}

define %num @sool_v2_sqlen(%v2 %a)
{
	%1 = tail call %num @sool_v2_dot(%v2 %a, %v2 %a)
	ret %num %1
}

define %num @sool_v2_len(%v2 %a)
{
	%1 = tail call %num @sool_v2_dot(%v2 %a, %v2 %a)
	%2 = tail call %num @llvm.sqrt.f64(%num %1)
	ret %num %2
}

define %v2 @sool_v2_polar(%v2 %a)
{
	%x = extractelement %v2 %a, i32 0
	%y = extractelement %v2 %a, i32 1
	%angle = tail call %num @atan2(%num %y, %num %x)
	
	%1 = fcmp oeq %num %x, 0.0
	br i1 %1, label %xzero, label %xnotzero
	
	xzero:
	%absy = tail call %num @abs(%num %y)
	br label %end
	
	xnotzero:
	%cosx = tail call %num @llvm.cos.f64(%num %x)
	%xoncosx = fdiv %num %x, %cosx
	br label %end
	
	end:
	%len = phi %num [%absy, %xzero], [%xoncosx, %xnotzero]
	%res = insertelement %v2 zeroinitializer, %num %len, i32 0
	%res2 = insertelement %v2 %res, %num %angle, i32 1
	
	ret %v2 %res2
}

define %v2 @sool_v2_rect(%v2 %a)
{
	%len = extractelement %v2 %a, i32 0
	%angle = extractelement %v2 %a, i32 1
	%cosa = tail call %num @llvm.cos.f64(%num %angle)
	%sina = tail call %num @llvm.sin.f64(%num %angle)
	
	%x = fmul %num %len, %cosa
	%y = fmul %num %len, %sina
	
	%res = insertelement %v2 zeroinitializer, %num %x, i32 0
	%res2 = insertelement %v2 %res, %num %y, i32 1
	
	ret %v2 %res2
}
