#!/usr/bin/env bash
set -Eeuo pipefail

[ -f versions.json ] # run "versions.sh" first

jqt='.jq-template.awk'
if [ -n "${BASHBREW_SCRIPTS:-}" ]; then
	jqt="$BASHBREW_SCRIPTS/jq-template.awk"
elif [ "$BASH_SOURCE" -nt "$jqt" ]; then
	wget -qO "$jqt" 'https://github.com/docker-library/bashbrew/raw/5f0c26381fb7cc78b2d217d58007800bdcfbcfa1/scripts/jq-template.awk'
fi

if [ "$#" -eq 0 ]; then
	versions="$(jq -r 'keys | map(@sh) | join(" ")' versions.json)"
	eval "set -- $versions"
fi

generated_warning() {
	cat <<-EOH
		#
		# NOTE: THIS DOCKERFILE IS GENERATED VIA "apply-templates.sh"
		#
		# PLEASE DO NOT EDIT IT DIRECTLY.
		#

	EOH
}

for version; do
	export version

	variants="$(jq -r '.[env.version].variants | map(@sh) | join(" ")' versions.json)"
	eval "variants=( $variants )"

	for dir in "${variants[@]}"; do
		mkdir -p "$version/$dir"

		variant="$(basename "$dir")" # "buster", "windowsservercore-1809", etc
		export variant

		case "$dir" in
			alpine*)
				template='Dockerfile-alpine.template'
				;;

			windows/*)
				windowsVariant="${variant%%-*}" # "windowsservercore", "nanoserver"
				windowsRelease="${variant#$windowsVariant-}" # "1809", "ltsc2016", etc
				windowsVariant="${windowsVariant#windows}" # "servercore", "nanoserver"
				export windowsVariant windowsRelease
				template="Dockerfile-windows-$windowsVariant.template"
				;;

			focal*)
				template='Dockerfile-ubuntu.template'
				;;

			*)
				template='Dockerfile-debian.template'
				;;
		esac

		echo "processing $version/$dir ..."

		{
			generated_warning
			gawk -f "$jqt" "$template"
		} > "$version/$dir/Dockerfile"
	done
done
