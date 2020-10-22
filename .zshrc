# Setup basic config stuff for history size, Vim keybindings, and the like
HISTFILE=~/.histfile
HISTSIZE=1000
SAVEHIST=1000
setopt autocd beep extendedglob notify
unsetopt nomatch

# Auto-completion (double-tab tab)
zstyle :compinstall filename '/home/terminus/.zshrc'
autoload -Uz compinit
compinit
zstyle ':completion:*' menu select

# Special prompt theme stuffs.
autoload -Uz promptinit
promptinit
prompt elite2

# Make Home, End and Delete do what they should do...
bindkey "^[[3~" delete-char
bindkey "^[[8~" end-of-line
bindkey "^[[7~" beginning-of-line

# Colorize ls output
alias ls='ls --color=auto'

# Variables
zpath="/dev/shm/zsh"
term=$(tty | grep -Eo '[0-9]{0,9}')
color="green"
oldcolor=$color
IsCommand=false
PROMPT=$'%F{$color}╔%f%F{$(shorthash "pts/$term")}%B☾%b%y%B☽%b%f%F{$color}═%f%F{$(shorthash $PWD)}%b%B⎛%b%d%B⎠%b%f$prompt_newline%F{$color}╚═> %f'
PROMPT2='%F{$color}╼═>%f'
PS2='%F{$color}╼═>%f'

# Make temp directory for syntax checking
if [[ ! -d $zpath ]]
then
	mkdir $zpath
fi

# Get unique list of programs from executable directories and ZSH builtins
set -A progarr /bin/* /sbin/* /usr/bin/* /usr/sbin/* /usr/local/bin/*
progarr=("${progarr[@]##*/}")
progarr[$((${#progarr}+1))]="alias"
progarr[$((${#progarr}+1))]="autoload"
progarr[$((${#progarr}+1))]="bg"
progarr[$((${#progarr}+1))]="break"
progarr[$((${#progarr}+1))]="builtin"
progarr[$((${#progarr}+1))]="cd"
progarr[$((${#progarr}+1))]="command"
progarr[$((${#progarr}+1))]="continue"
progarr[$((${#progarr}+1))]="dirs"
progarr[$((${#progarr}+1))]="disable"
progarr[$((${#progarr}+1))]="disown"
progarr[$((${#progarr}+1))]="echo"
progarr[$((${#progarr}+1))]="emulate"
progarr[$((${#progarr}+1))]="enable"
progarr[$((${#progarr}+1))]="eval"
progarr[$((${#progarr}+1))]="exec"
progarr[$((${#progarr}+1))]="exit"
progarr[$((${#progarr}+1))]="export"
progarr[$((${#progarr}+1))]="false"
progarr[$((${#progarr}+1))]="fc"
progarr[$((${#progarr}+1))]="fg"
progarr[$((${#progarr}+1))]="float"
progarr[$((${#progarr}+1))]="functions"
progarr[$((${#progarr}+1))]="getln"
progarr[$((${#progarr}+1))]="getopts"
progarr[$((${#progarr}+1))]="hash"
progarr[$((${#progarr}+1))]="integer"
progarr[$((${#progarr}+1))]="jobs"
progarr[$((${#progarr}+1))]="kill"
progarr[$((${#progarr}+1))]="let"
progarr[$((${#progarr}+1))]="limit"
progarr[$((${#progarr}+1))]="local"
progarr[$((${#progarr}+1))]="logout"
progarr[$((${#progarr}+1))]="noglob"
progarr[$((${#progarr}+1))]="popd"
progarr[$((${#progarr}+1))]="printf"
progarr[$((${#progarr}+1))]="prompt"
progarr[$((${#progarr}+1))]="pushd"
progarr[$((${#progarr}+1))]="pushln"
progarr[$((${#progarr}+1))]="pwd"
progarr[$((${#progarr}+1))]="return"
progarr[$((${#progarr}+1))]="setopt"
progarr[$((${#progarr}+1))]="shift"
progarr[$((${#progarr}+1))]="source"
progarr[$((${#progarr}+1))]="suspend"
progarr[$((${#progarr}+1))]="test"
progarr[$((${#progarr}+1))]="trap"
progarr[$((${#progarr}+1))]="true"
progarr[$((${#progarr}+1))]="ttyctl"
progarr[$((${#progarr}+1))]="type"
progarr[$((${#progarr}+1))]="typeset"
progarr[$((${#progarr}+1))]="ulimit"
progarr[$((${#progarr}+1))]="umask"
progarr[$((${#progarr}+1))]="unalias"
progarr[$((${#progarr}+1))]="unhash"
progarr[$((${#progarr}+1))]="unlimit"
progarr[$((${#progarr}+1))]="unset"
progarr[$((${#progarr}+1))]="unsetopt"
progarr[$((${#progarr}+1))]="wait"
progarr[$((${#progarr}+1))]="whence"
progarr[$((${#progarr}+1))]="where"
progarr[$((${#progarr}+1))]="which"
progarr[$((${#progarr}+1))]="zcompile"

# Sort list, case-sensative
IFS=$'\n' progarr=($(LC_COLLATE=C sort <<<"${progarr[*]}")); unset IFS
set -A progarr ${(u)progarr[@]}

# Get list of starting characters and their indexes to optimize searching
declare -A progarr_firstchar
declare -A progarr_firstcharindex
declare -A buffarr_old

prog_firstchar=""

for (( prog=0; prog <= ${#progarr}; prog++ ))
do
	if [ $prog -eq ${#progarr} ]
	then
		progarr_firstchar[$(($#progarr_firstchar))]=$null
		progarr_firstcharindex[$(($#progarr_firstcharindex))]=${#progarr}
	fi

	if [[ ${progarr[$prog]:0:1} != $prog_firstchar ]]
	then
		progarr_firstchar[$(($#progarr_firstchar))]=${progarr[$prog]:0:1}
		progarr_firstcharindex[$(($#progarr_firstcharindex))]=$prog
		prog_firstchar=${progarr[$prog]:0:1}
	fi

done

# Syntax checker
function syntax_validation
{
	for (( firstchar_index=0; firstchar_index < ${#progarr_firstchar}; firstchar_index++ ))
	do
		# Only check commands which start with the same first letter
		if [[ ${buffarr[$buff_index]:0:1} == ${progarr_firstchar[$firstchar_index]} ]] && [[ -n ${progarr_firstchar[$firstchar_index]} ]]
		then
			# Check to see if command string contains known commands
			for (( prog_index=${progarr_firstcharindex[$firstchar_index]}; prog_index <= ${progarr_firstcharindex[$(($firstchar_index+1))]}; prog_index++ ))
			do
				if [[ ${progarr[$prog_index]} == ${buffarr[$buff_index]} ]]
				then
					IsCommand=true
					break

				elif [ $prog_index -eq ${progarr_firstcharindex[$(($firstchar_index+1))]} ]
				then
					IsCommand=false
				fi
			done
		fi
	done
}

# Check for command after last to cover cases like "sudo" and "nohup"
function check_next_command
{
	((buff_index++))

	if [[ -n $(echo ${buffarr[$buff_index]} | grep "sudo") ]] || [[ -n $(echo ${buffarr[$buff_index]} | grep "nohup") ]]
	then
		syntax_validation
		((buff_index++))

		if [[ $buff_index -lt ${#buffarr} ]]
		then
			syntax_validation
		fi
	elif
	then
		syntax_validation
	fi
}

# Syntax checker wrapper
function syntax_validation_precheck
{
	if [[ -n $(echo "$BUFFER" | grep -Eo '[[:alnum:]]') ]]
	then
		IsCommand="unknown"
	else
		color="green"
		return
	fi

	# Extract each component of the current command string
	echo $BUFFER | grep -Eo '[[:alnum:]]{1,100}|\|\s|\|\||<\s|\$\(|\&\&' > "$zpath/buffer"

	# Create array from buffer
	buff_index=-1
	declare -A buffarr
	for buffline in "${(@f)"$(<$zpath/buffer)"}"
	{
		buffarr[${#buffarr}]=$buffline
	}

	# Check for difference between last buffer and this buffer so that we only focus on that term
	for (( i=0; i < ${#buffarr}; i++ ))
	do
		if [[ ${buffarr[$i]} != ${buffarr_old[$i]} ]] && [[ $buff_index -eq -1 ]]
		then
			buff_index=$i
			break
		fi
	done

	for (( i=0; i < ${#buffarr}; i++ ))
	do
		buffarr_old[$i]=${buffarr[$i]}
	done

	# First term and contains alphanumeric characters
	if [[ $buff_index -eq 0 ]] && [[ -n $(echo ${buffarr[$buff_index]} | grep -Eo '[[:alnum:]]{1,100}') ]]
	then
		syntax_validation

	# sudo
	elif [[ -n $(echo ${buffarr[$(($buff_index-1))]} | grep "sudo") ]] || [[ -n $(echo ${buffarr[$(($buff_index-1))]} | grep "nohup") ]]
	then
		syntax_validation

	# AND, OR
	elif [[ -n $(echo ${buffarr[$(($buff_index-1))]} | grep "&&") ]] || [[ -n $(echo ${buffarr[$(($buff_index-1))]} | grep "||") ]]
	then
		syntax_validation

	# Pipe
	elif [[ -n $(echo ${buffarr[$(($buff_index-1))]} | grep "|") ]]
	then
		syntax_validation

	# Command expression
	elif [[ -n $(echo "${buffarr[$buff_index]}" | grep "\$(") ]]
	then
		if [[ $buff_index -lt ${#buffarr} ]]
		then
			check_next_command

			if [ $IsCommand == false ]
			then
				((buff_index++))

				buffarr[$buff_index]=${buffarr[$(($buff_index-1))]:2}${buffarr[$buff_index]}
				
				if [[ -n ${buffarr[$buff_index]} ]]
				then
					syntax_validation
				fi
			fi
		fi

	elif [[ -n $(echo "${buffarr[$(($buff_index-1))]}" | grep "\$(") ]]
	then
		((buff_index--))
		if [[ $buff_index -lt ${#buffarr} ]]
		then
			check_next_command

			if [ $IsCommand == false ]
			then
				((buff_index++))

				buffarr[$buff_index]=${buffarr[$(($buff_index-1))]:2}${buffarr[$buff_index]}
				
				if [[ -n ${buffarr[$buff_index]} ]]
				then
					syntax_validation
				fi
			fi
		fi
	fi

	if [ $IsCommand == true ]
	then
		color="green"
	elif [ $IsCommand == false ]
	then
		color="red"
	fi
}

function do_precheck_and_redraw_prompt
{
	syntax_validation_precheck
	if [[ $color != $oldcolor ]]
	then
		zle reset-prompt
		oldcolor=$color
	fi
}

# Trap function for each key
function trap_A
{
	BUFFER=$LBUFFER"A"$RBUFFER
	zle vi-forward-char
	do_precheck_and_redraw_prompt
}
function trap_B
{
	BUFFER=$LBUFFER"B"$RBUFFER
	zle vi-forward-char
	do_precheck_and_redraw_prompt
}
function trap_C
{
	BUFFER=$LBUFFER"C"$RBUFFER
	zle vi-forward-char
	do_precheck_and_redraw_prompt
}
function trap_D
{
	BUFFER=$LBUFFER"D"$RBUFFER
	zle vi-forward-char
	do_precheck_and_redraw_prompt
}
function trap_E
{
	BUFFER=$LBUFFER"E"$RBUFFER
	zle vi-forward-char
	do_precheck_and_redraw_prompt
}
function trap_F
{
	BUFFER=$LBUFFER"F"$RBUFFER
	zle vi-forward-char
	do_precheck_and_redraw_prompt
}
function trap_G
{
	BUFFER=$LBUFFER"G"$RBUFFER
	zle vi-forward-char
	do_precheck_and_redraw_prompt
}
function trap_H
{
	BUFFER=$LBUFFER"H"$RBUFFER
	zle vi-forward-char
	do_precheck_and_redraw_prompt
}
function trap_I
{
	BUFFER=$LBUFFER"I"$RBUFFER
	zle vi-forward-char
	do_precheck_and_redraw_prompt
}
function trap_J
{
	BUFFER=$LBUFFER"J"$RBUFFER
	zle vi-forward-char
	do_precheck_and_redraw_prompt
}
function trap_K
{
	BUFFER=$LBUFFER"K"$RBUFFER
	zle vi-forward-char
	do_precheck_and_redraw_prompt
}
function trap_L
{
	BUFFER=$LBUFFER"L"$RBUFFER
	zle vi-forward-char
	do_precheck_and_redraw_prompt
}
function trap_M
{
	BUFFER=$LBUFFER"M"$RBUFFER
	zle vi-forward-char
	do_precheck_and_redraw_prompt
}
function trap_N
{
	BUFFER=$LBUFFER"N"$RBUFFER
	zle vi-forward-char
	do_precheck_and_redraw_prompt
}
function trap_O
{
	BUFFER=$LBUFFER"O"$RBUFFER
	zle vi-forward-char
	do_precheck_and_redraw_prompt
}
function trap_P
{
	BUFFER=$LBUFFER"P"$RBUFFER
	zle vi-forward-char
	do_precheck_and_redraw_prompt
}
function trap_Q
{
	BUFFER=$LBUFFER"Q"$RBUFFER
	zle vi-forward-char
	do_precheck_and_redraw_prompt
}
function trap_R
{
	BUFFER=$LBUFFER"R"$RBUFFER
	zle vi-forward-char
	do_precheck_and_redraw_prompt
}
function trap_S
{
	BUFFER=$LBUFFER"S"$RBUFFER
	zle vi-forward-char
	do_precheck_and_redraw_prompt
}
function trap_T
{
	BUFFER=$LBUFFER"T"$RBUFFER
	zle vi-forward-char
	do_precheck_and_redraw_prompt
}
function trap_U
{
	BUFFER=$LBUFFER"U"$RBUFFER
	zle vi-forward-char
	do_precheck_and_redraw_prompt
}
function trap_V
{
	BUFFER=$LBUFFER"V"$RBUFFER
	zle vi-forward-char
	do_precheck_and_redraw_prompt
}
function trap_W
{
	BUFFER=$LBUFFER"W"$RBUFFER
	zle vi-forward-char
	do_precheck_and_redraw_prompt
}
function trap_X
{
	BUFFER=$LBUFFER"X"$RBUFFER
	zle vi-forward-char
	do_precheck_and_redraw_prompt
}
function trap_Y
{
	BUFFER=$LBUFFER"Y"$RBUFFER
	zle vi-forward-char
	do_precheck_and_redraw_prompt
}
function trap_Z
{
	BUFFER=$LBUFFER"Z"$RBUFFER
	zle vi-forward-char
	do_precheck_and_redraw_prompt
}
function trap_a
{
	BUFFER=$LBUFFER"a"$RBUFFER
	zle vi-forward-char
	do_precheck_and_redraw_prompt
}
function trap_b
{
	BUFFER=$LBUFFER"b"$RBUFFER
	zle vi-forward-char
	do_precheck_and_redraw_prompt
}
function trap_c
{
	BUFFER=$LBUFFER"c"$RBUFFER
	zle vi-forward-char
	do_precheck_and_redraw_prompt
}
function trap_d
{
	BUFFER=$LBUFFER"d"$RBUFFER
	zle vi-forward-char
	do_precheck_and_redraw_prompt
}
function trap_e
{
	BUFFER=$LBUFFER"e"$RBUFFER
	zle vi-forward-char
	do_precheck_and_redraw_prompt
}
function trap_f
{
	BUFFER=$LBUFFER"f"$RBUFFER
	zle vi-forward-char
	do_precheck_and_redraw_prompt
}
function trap_g
{
	BUFFER=$LBUFFER"g"$RBUFFER
	zle vi-forward-char
	do_precheck_and_redraw_prompt
}
function trap_h
{
	BUFFER=$LBUFFER"h"$RBUFFER
	zle vi-forward-char
	do_precheck_and_redraw_prompt
}
function trap_i
{
	BUFFER=$LBUFFER"i"$RBUFFER
	zle vi-forward-char
	do_precheck_and_redraw_prompt
}
function trap_j
{
	BUFFER=$LBUFFER"j"$RBUFFER
	zle vi-forward-char
	do_precheck_and_redraw_prompt
}
function trap_k
{
	BUFFER=$LBUFFER"k"$RBUFFER
	zle vi-forward-char
	do_precheck_and_redraw_prompt
}
function trap_l
{
	BUFFER=$LBUFFER"l"$RBUFFER
	zle vi-forward-char
	do_precheck_and_redraw_prompt
}
function trap_m
{
	BUFFER=$LBUFFER"m"$RBUFFER
	zle vi-forward-char
	do_precheck_and_redraw_prompt
}
function trap_n
{
	BUFFER=$LBUFFER"n"$RBUFFER
	zle vi-forward-char
	do_precheck_and_redraw_prompt
}
function trap_o
{
	BUFFER=$LBUFFER"o"$RBUFFER
	zle vi-forward-char
	do_precheck_and_redraw_prompt
}
function trap_p
{
	BUFFER=$LBUFFER"p"$RBUFFER
	zle vi-forward-char
	do_precheck_and_redraw_prompt
}
function trap_q
{
	BUFFER=$LBUFFER"q"$RBUFFER
	zle vi-forward-char
	do_precheck_and_redraw_prompt
}
function trap_r
{
	BUFFER=$LBUFFER"r"$RBUFFER
	zle vi-forward-char
	do_precheck_and_redraw_prompt
}
function trap_s
{
	BUFFER=$LBUFFER"s"$RBUFFER
	zle vi-forward-char
	do_precheck_and_redraw_prompt
}
function trap_t
{
	BUFFER=$LBUFFER"t"$RBUFFER
	zle vi-forward-char
	do_precheck_and_redraw_prompt
}
function trap_u
{
	BUFFER=$LBUFFER"u"$RBUFFER
	zle vi-forward-char
	do_precheck_and_redraw_prompt
}
function trap_v
{
	BUFFER=$LBUFFER"v"$RBUFFER
	zle vi-forward-char
	do_precheck_and_redraw_prompt
}
function trap_w
{
	BUFFER=$LBUFFER"w"$RBUFFER
	zle vi-forward-char
	do_precheck_and_redraw_prompt
}
function trap_x
{
	BUFFER=$LBUFFER"x"$RBUFFER
	zle vi-forward-char
	do_precheck_and_redraw_prompt
}
function trap_y
{
	BUFFER=$LBUFFER"y"$RBUFFER
	zle vi-forward-char
	do_precheck_and_redraw_prompt
}
function trap_z
{
	BUFFER=$LBUFFER"z"$RBUFFER
	zle vi-forward-char
	do_precheck_and_redraw_prompt
}
function trap_0
{
	BUFFER=$LBUFFER"0"$RBUFFER
	zle vi-forward-char
	do_precheck_and_redraw_prompt
}
function trap_1
{
	BUFFER=$LBUFFER"1"$RBUFFER
	zle vi-forward-char
	do_precheck_and_redraw_prompt
}
function trap_2
{
	BUFFER=$LBUFFER"2"$RBUFFER
	zle vi-forward-char
	do_precheck_and_redraw_prompt
}
function trap_3
{
	BUFFER=$LBUFFER"3"$RBUFFER
	zle vi-forward-char
	do_precheck_and_redraw_prompt
}
function trap_4
{
	BUFFER=$LBUFFER"4"$RBUFFER
	zle vi-forward-char
	do_precheck_and_redraw_prompt
}
function trap_5
{
	BUFFER=$LBUFFER"5"$RBUFFER
	zle vi-forward-char
	do_precheck_and_redraw_prompt
}
function trap_6
{
	BUFFER=$LBUFFER"6"$RBUFFER
	zle vi-forward-char
	do_precheck_and_redraw_prompt
}
function trap_7
{
	BUFFER=$LBUFFER"7"$RBUFFER
	zle vi-forward-char
	do_precheck_and_redraw_prompt
}
function trap_8
{
	BUFFER=$LBUFFER"8"$RBUFFER
	zle vi-forward-char
	do_precheck_and_redraw_prompt
}
function trap_9
{
	BUFFER=$LBUFFER"9"$RBUFFER
	zle vi-forward-char
	do_precheck_and_redraw_prompt
}
function trap_backspace
{
	zle backward-delete-char
	do_precheck_and_redraw_prompt
}
function trap_enter
{
	color="green"
	zle accept-line
}
function trap_delete
{
	zle delete-char
	do_precheck_and_redraw_prompt
}
function trap_space
{
	BUFFER=$LBUFFER" "$RBUFFER
	zle vi-forward-char
	do_precheck_and_redraw_prompt
}

zle -N do_precheck_and_redraw_prompt

# Bind all letters, numbers, and backspace to it
for letter in {A..Z}
do
	bindkey $letter trap_$letter
	zle -N trap_$letter
done

for letter in {a..z}
do
	bindkey $letter trap_$letter
	zle -N trap_$letter
done

for number in {0..9}
do
	bindkey $number trap_$number
	zle -N trap_$number
done

bindkey '^?' trap_backspace
zle -N trap_backspace

bindkey '^M' trap_enter
zle -N trap_enter

bindkey '^[[3~' trap_delete
zle -N trap_delete

bindkey ' ' trap_space
zle -N trap_space

export EDITOR='vim'
