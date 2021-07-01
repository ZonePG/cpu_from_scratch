   .org 0x0    # 指示程序从地址0x0开始
   .set noat   # 允许使用自由使用寄存器 $1
   .global _start # 定义一个全局符号_start
_start:
   ori  $1, $0, 0xffff                  
   sll  $1, $1, 16
   ori  $1, $1, 0xfffb           # $1 = -5
   ori  $2, $0, 6                # $2 = 6

   mult $1, $2                  # hi = 0xffffffff
                                # lo = 0xffffffe2, -30

   madd $1, $2                  # hi = 0xffffffff
                                # lo = 0xffffffc4, -60

   maddu $1, $2                 # hi = 0x5
                                # lo = 0xffffffa6

   msub $1, $2                  # hi = 0x5
                                # lo = 0xffffffc4   

   msubu $1, $2                 # hi = 0xffffffff
                                # lo = 0xffffffe2
