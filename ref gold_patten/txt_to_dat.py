#-----this is for dat
def txt_to_dat(file1,file2):
    x=''
    with open(file1,'r') as f:
        b1=f.read()
        we1=[]
        we1=b1.split('\n')
        del we1[-1]
        
    for seq,name in enumerate(we1):
        x=x+name
    
    with open(file2,'w') as f:
        f.write(x)

# txt_to_dat('ifmap.txt','ifmap.dat')
# txt_to_dat('m0exponent.txt','m0exponent.dat')
# txt_to_dat('bias1.txt','bias1.dat')
# txt_to_dat('bias2.txt','bias2.dat')
# txt_to_dat('bias3.txt','bias3.dat')
# txt_to_dat('fully_b1.txt','fully_b1.dat')
# txt_to_dat('fully_b2.txt','fully_b2.dat')
# txt_to_dat('weight1.txt','weight1.dat')
# txt_to_dat('weight2.txt','weight2.dat')
# txt_to_dat('weight3.txt','weight3.dat')
# txt_to_dat('fully1.txt','fully1.dat')
# txt_to_dat('fully2.txt','fully2.dat')

# txt_to_dat('layer0_INPUT_MAP_1.txt','layer0_INPUT_MAP_1.dat')
# txt_to_dat('layer0_INPUT_MAP_2.txt','layer0_INPUT_MAP_2.dat')
# txt_to_dat('layer0_INPUT_MAP_3.txt','layer0_INPUT_MAP_3.dat')
# txt_to_dat('layer0_INPUT_MAP_4.txt','layer0_INPUT_MAP_4.dat')
# txt_to_dat('layer0_INPUT_MAP_5.txt','layer0_INPUT_MAP_5.dat')

#-----this is for dat
def dat_toghter():
    with open('layer0_INPUT_MAP_5.dat','r') as f:
        b1=f.read()
    with open('m0exponent.dat','r') as f:
        b12=f.read()
    with open('bias1.dat','r') as f:
        b2=f.read()
    with open('weight1.dat','r') as f:
        b3=f.read()
    with open('bias2.dat','r') as f:
        b4=f.read()
    with open('weight2.dat','r') as f:
        b5=f.read()
    with open('bias3.dat','r') as f:
        b6=f.read()
    with open('weight3.dat','r') as f:
        b7=f.read()
    with open('fully_b1.dat','r') as f:
        b8=f.read()
    with open('fully1.dat','r') as f:
        b9=f.read()
    with open('fully_b2.dat','r') as f:
        b10=f.read()
    with open('fully2.dat','r') as f:
        b11=f.read()
    s=b1+b12+b2+b3+b4+b5+b6+b7+b8+b9+b10+b11
    with open('all_n5.dat','w') as f:
        f.write(s)

# dat_toghter()

#-----this is for coe
def txt_to_coe(file1,file2):
    with open(file1,'r') as f:
        b1=f.read()
        we1=[]
        we1=b1.split('\n')
    
    with open(file2,'w') as f:
        radix='memory_initialization_radix=16;\n'
        vector='memory_initialization_vector=\n'
        c=radix+vector
        for seq,name in enumerate(we1):
            if seq==(len(we1)-1):
                c=c+name+';'
            else:
                c=c+name+',\n'
        f.write(c)

# txt_to_coe('m0exponent.txt','m0exponent.coe')
# txt_to_coe('bias1.txt','bias1.coe')
# txt_to_coe('bias2.txt','bias2.coe')
# txt_to_coe('bias3.txt','bias3.coe')
# txt_to_coe('fully_b1.txt','fully_b1.coe')
# txt_to_coe('fully_b2.txt','fully_b2.coe')
# txt_to_coe('weight1.txt','weight1.coe')
# txt_to_coe('weight2.txt','weight2.coe')
# txt_to_coe('weight3.txt','weight3.coe')
# txt_to_coe('fully1.txt','fully1.coe')
# txt_to_coe('fully2.txt','fully2.coe')

#-----this is for coe part 2
def coe_toghter(file2):
    with open('m0exponent.txt','r') as f:
        b1=f.read()
        we1=[]
        we1=b1.split('\n')
    with open('bias1.txt','r') as f:
        b1=f.read()
        we2=[]
        we2=b1.split('\n')
    with open('weight1.txt','r') as f:
        b1=f.read()
        we3=[]
        we3=b1.split('\n')
    with open('bias2.txt','r') as f:
        b1=f.read()
        we4=[]
        we4=b1.split('\n')
    with open('weight2.txt','r') as f:
        b1=f.read()
        we5=[]
        we5=b1.split('\n')
    with open('bias3.txt','r') as f:
        b1=f.read()
        we6=[]
        we6=b1.split('\n')
    with open('weight3.txt','r') as f:
        b1=f.read()
        we7=[]
        we7=b1.split('\n')
    with open('fully_b1.txt','r') as f:
        b1=f.read()
        we8=[]
        we8=b1.split('\n')
    with open('fully1.txt','r') as f:
        b1=f.read()
        we9=[]
        we9=b1.split('\n')
    with open('fully_b2.txt','r') as f:
        b1=f.read()
        we10=[]
        we10=b1.split('\n')
    with open('fully2.txt','r') as f:
        b1=f.read()
        we11=[]
        we11=b1.split('\n')
    
    with open(file2,'w') as f:
        radix='memory_initialization_radix=16;\n'
        vector='memory_initialization_vector=\n'
        c=radix+vector
        for seq,name in enumerate(we1):
            c=c+name+',\n'
        for seq,name in enumerate(we2):
            c=c+name+',\n'
        for seq,name in enumerate(we3):
            c=c+name+',\n'
        for seq,name in enumerate(we4):
            c=c+name+',\n'
        for seq,name in enumerate(we5):
            c=c+name+',\n'
        for seq,name in enumerate(we6):
            c=c+name+',\n'
        for seq,name in enumerate(we7):
            c=c+name+',\n'
        for seq,name in enumerate(we8):
            c=c+name+',\n'
        for seq,name in enumerate(we9):
            c=c+name+',\n'
        for seq,name in enumerate(we10):
            c=c+name+',\n'
        for seq,name in enumerate(we11):
            c=c+name+',\n'
        f.write(c)

# coe_toghter('data.coe')