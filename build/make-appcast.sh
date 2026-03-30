#!/usr/bin/env bash

GITROOT=$(git rev-parse --show-toplevel)
AUTHOR=ruittenb
PROJECT=Spaceman
PBXPROJ=$GITROOT/$PROJECT.xcodeproj/project.pbxproj
BUILDDIR=build
URL=https://api.github.com/repos/$AUTHOR/$PROJECT/releases/latest

############################################################################
# functions

print_xml() {
    cat <<_END_XML_
<?xml version="1.0" standalone="yes"?>
<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" version="2.0">
    <channel>
        <title>${PROJECT}</title>
        <item>
            <title>${title}</title>
            <description>
                <![CDATA[
                    ${description_title:+<p>${description_title}</p>}
                    <ul>
${description_items}
                    </ul>
                ]]>
            </description>
            <pubDate>${pub_date}</pubDate>
            <sparkle:minimumSystemVersion>${minimum_system_version}</sparkle:minimumSystemVersion>
            <enclosure
                url="https://github.com/${AUTHOR}/${PROJECT}/releases/download/v${version}/${image_file}"
                sparkle:version="${numeric_version}"
                sparkle:shortVersionString="${friendly_version}"
                type="application/octet-stream"
                ${signature_and_length}
            />
        </item>
    </channel>
</rss>
_END_XML_
}

get_github_release() {
    release_data=$(wget -qO- "$URL")
}

bulletpoint() {
    awk '{
        gsub("\r", "");
        if (/^ *$/) next;
        printf "%24s<li>%s</li>\n", "", $0;
    }'
}

gather_data() {
    local sparkle_dir=$(
        ls -d1 ~/Library/Developer/Xcode/DerivedData/Spaceman-*/SourcePackages/artifacts/sparkle/Sparkle/bin | head -1
    )

    local body=$(echo "$release_data" | jq -r .body)
    local published_at=$(echo "$release_data" | jq -r .published_at)
    local vversion=$(echo "$release_data" | jq -r .tag_name)

    title=$(echo "$release_data" | jq -r .name)
    image_file=$(echo "$release_data" | jq -r '.assets[].name' | head -1)

    if [[ "$image_file" != *.dmg ]]; then
        echo "No .dmg file found in latest release"
        return 1
    fi

    local description_first_line=$(printf '%s' "$body" | head -1 | tr -d '\r')
    if [[ "$description_first_line" =~ ^v[0-9]+\.[0-9]+ ]]; then
        description_title="$description_first_line"
        description_items=$(printf '%s' "$body" | tail -n +2 | bulletpoint)
    else
        description_title=""
        description_items=$(printf '%s' "$body" | bulletpoint)
    fi
    
    pub_date=$(gdate -R -d "$published_at")
    version=${vversion#v}
    friendly_version=${version}
    numeric_version=${version%-R}
    minimum_system_version=$(awk -F'[=; ]{1,}' '/MACOSX_DEPLOYMENT_TARGET/ { print $2; exit }' "$PBXPROJ")

    signature_and_length=$("$sparkle_dir"/sign_update "$BUILDDIR/$image_file" | awk '{ print $2 "\n" $1 }')
    return # returns the exit status of sign_update
}

main() {
    get_github_release
    if gather_data; then
        print_xml
    else
        echo "Aborted"
        exit 1
    fi
}

############################################################################
# main

main "$@"

