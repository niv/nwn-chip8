default: watch

compile:
  nwn_script_comp --no-key --no-ovr \
    --dirs ~/code/nwn/gamedata/latest-resource-override \
    -c .

alias build := compile

watch: compile
  fswatch -0  -i '\.nss$' -e '.*'  . | xargs -0 -n1 -I{} \
    {{just_executable()}} compile

