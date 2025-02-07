# ------------------------------------------
# .aliases/docker
# ------------------------------------------

{{- define "dockeraliases" -}}

# --- env vars ---

DOCKER_ROOT="$HOME/docker"

# source machine specific env vars (if they exist)
if [[ -f "$HOME/docker/shared/config/zsh_aliases.env" ]]; then
  source $HOME/docker/shared/config/zsh_aliases.env 
fi 

# --- functions ---

# compose file handler > all compose files
docker_compose_all() {
    local command=$1
    local compose_files=()
    
    # add base compose file if it exists
    if [[ -f "$HOME/docker/compose.yml" ]]; then
        compose_files+=("-f" "$HOME/docker/compose.yml")
    fi
    
    # add all additional compose files
    for file in "$HOME/docker"/compose.*.yml; do
        if [[ -f "$file" ]]; then
            compose_files+=("-f" "$file")
        fi
    done
    
    if [ ${#compose_files[@]} -eq 0 ]; then
        echo "No compose files found in $HOME/docker/"
        return 1
    fi
    
    echo "Running command across these files:"
    printf '%s\n' "${compose_files[@]}" | sed 's/-f //'
    echo "---"
    
    sudo docker compose "${compose_files[@]}" $command
}

# compose file handler > compose file 'wildcard'
docker_compose_wildcard() {
    local command=$1
    local stack=$2
    
    if [[ "$stack" == "all" ]]; then
        echo "Error: Use dcup.all, dcdown.all etc. for all stacks"
        return 1
    }
    
    local compose_file="$HOME/docker/compose.${stack}.yml"
    
    if [[ -f "$compose_file" ]]; then
        sudo docker compose -f "$HOME/docker/compose.yml" -f "$compose_file" $command
    else
        echo "Error: Compose file for stack '${stack}' not found at ${compose_file}"
        return 1
    fi
}

# list available compose stacks
docker_compose_stacks() {
    echo "Available compose files:"
    if [[ -f "$HOME/docker/compose.yml" ]]; then
        echo "- compose.yml (base)"
    fi
    find "$HOME/docker" -name "compose.*.yml" -exec basename {} \; | sed 's/compose\.\(.*\)\.yml/- \1/'
}


# --- containers ---

# start
alias dstart='sudo docker start' # usage: dstart container_name
alias dstopall='sudo docker start $(sudo docker ps -aq)' # dstart all containers

# stop
alias dstop='sudo docker stop' # usage: dstop container_name
alias dstopall='sudo docker stop $(sudo docker ps -aq)' # stop all containers

# restart
alias drestart='sudo docker restart' # usage: dstart container_name
alias drestartall='sudo docker restart $(sudo docker ps -aq)' # dstart all containers

# rm
alias drm='sudo docker rm' # usage: drm container_name
alias drmall='sudo docker rm $(sudo docker ps -aq)' # remove all containers

# shell
alias dexec='sudo docker exec -ti' # usage: dexec container_name


# --- compose / stacks ---

# define docker root folder compose file
alias dc='sudo docker compose -f $DOCKER_ROOT/compose.yml' # core

# run basic / core compose file
alias dcup='dc up -d --build --remove-orphans' # up the stack
alias dcdown='dc down --remove-orphans' # down the stack
alias dcstart='dc start' # usage: dcstart container_name
alias dcstop='dc stop' # usage: dcstop container_name
alias dcrec='dc up -d --force-recreate --remove-orphans' # usage: dcrec container_name
alias dcrestart='dc restart' # usage: dcrestart container_name
alias dcpull='dc pull' # usage: dcpull to pull all new images or dcpull container_name

# run wildcard compose / merge files
alias dcup.='docker_compose_wildcard "up -d --build --remove-orphans"'
alias dcdown.='docker_compose_wildcard "down --remove-orphans"'
alias dcstart.='docker_compose_wildcard "start"'
alias dcstop.='docker_compose_wildcard "stop"'
alias dcrec.='docker_compose_wildcard "up -d --force-recreate --remove-orphans"'
alias dcrestart.='docker_compose_wildcard "restart"'
alias dcpull.='docker_compose_wildcard "pull"'

# run all compose / merge files in docker root
alias dcup.all='docker_compose_all "up -d --build --remove-orphans"'
alias dcdown.all='docker_compose_all "down --remove-orphans"'
alias dcstart.all='docker_compose_all "start"'
alias dcstop.all='docker_compose_all "stop"'
alias dcrec.all='docker_compose_all "up -d --force-recreate --remove-orphans"'
alias dcrestart.all='docker_compose_all "restart"'
alias dcpull.all='docker_compose_all "pull"'

# List stacks alias
alias dcls='docker_compose_stacks'


# --- system ---

# ps
alias dps='sudo docker ps -a' # running docker processes
alias dpss='sudo docker ps -a --format "table {{ `{{` }}.Names{{ `}}` }}\t{{ `{{` }}.State{{ `}}` }}\t{{ `{{` }}.Status{{ `}}` }}\t{{ `{{` }}.Image{{ `}}` }}" | (sed -u 1q; sort)' # list all processes in a table (go syntax) 


# df
alias ddf='sudo docker system df' # docker data usage (/var/lib/docker)

# system prune
alias ddelimages='sudo docker rmi $(sudo docker images -q)' # delete unused images
alias dprunesys='sudo docker system prune -a' # remove unsed docker data


# --- images ---

alias dimg='sudo docker image ls' # list images
alias dpruneimg='sudo docker image prune' # remove unused images


# --- volumes ---

alias dvol='sudo docker volume ls' # list volumes
alias dprunevol='sudo docker volume prune' # remove unused volumes


# --- logs ---

alias dlogs='sudo docker logs -tf --tail="50" ' # usage: dlogs container_name
alias dlogsize='sudo du -ch $(sudo docker inspect --format={{ `{{` }}.LogPath{{ `}}` }} $(sudo docker ps -qa)) | sort -h' # see the size of docker containers (go syntax) 


# --- network ---

alias dnet='sudo docker network ls' # list networks 
alias dips="sudo docker ps -q | xargs -n 1 sudo docker inspect -f '{{ `{{` }}.Name{{ `}}` }}%tab%{{ `{{` }}range .NetworkSettings.Networks{{ `}}` }}{{ `{{` }}.IPAddress{{ `}}` }}%tab%{{ `{{` }}end{{ `}}` }}' | sed 's#%tab%#\t#g' | sed 's#/##g' | sort | column -t -N NAME,IP\(s\) -o \$'\t'" # list all containers with their IP addresses


{{- end -}}
{{ template "dockeraliases" . }}