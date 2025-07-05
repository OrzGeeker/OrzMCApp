#!/usr/bin/env bash
#-*- coding: utf-8 -*-

# parameters
scheme=OrzMC
team_id=2N62934Y28
configuration=Release
destination="generic/platform=macOS"
gh_pages_branch="gh-pages"

apple_id="824219521@qq.com"
app_specific_password="bbgb-nzuk-trqz-uzax"
notary_timeout_duration="5m"

# path defination
git_repo_dir=$(git rev-parse --show-toplevel)
git_url=$(git remote get-url origin)
extract_repo_name() {
    local url="$1"
    # 移除协议前缀
    url=${url#*://}
    # 移除用户名和密码部分（如果存在）
    url=${url#*@}
    # 提取路径部分
    url=${url#*/}
    # 移除 .git 后缀
    url=${url%.git}
    # 如果URL以/结尾，移除最后的/
    url=${url%/}
    # 返回最后一个路径部分
    echo "${url##*/}"
}
git_repo_name=$(extract_repo_name ${git_url})
extract_user_repo() {
    local url="$1"
    # 移除协议前缀（https://, git://, ssh://等）
    url=${url#*://}
    # 处理git@格式（git@github.com:user/repo.git）
    url=${url#*@}
    # 替换:为/（处理git@格式）
    url=${url/://}
    # 移除.git后缀
    url=${url%.git}
    # 提取user/repo部分
    echo "${url#*/}"
}
git_user_repo_name=$(extract_user_repo ${git_url})
derived_data_path="$git_repo_dir/DerivedData"
build_dir=$git_repo_dir/build
archive_path="$build_dir/$scheme.xcarchive"
app_dir=$git_repo_dir
docs_dir="${app_dir}/docs"
product_dir=$app_dir/products

export_options_plist=$app_dir/exportOptions.plist
export_path=$app_dir
export_app=$export_path/$scheme.app
export_app_zip=$export_app.zip

plistBuddyBin=/usr/libexec/PlistBuddy
app_info_plist="$export_app/Contents/Info.plist"

sparkle_bin=$derived_data_path/SourcePackages/artifacts/sparkle/Sparkle/bin

# Publish App
function remove() {
    for path in $*
    do
        # remove dir if exist
        if [ -d $path ]; then
            rm -rf $path
            echo removed dir: $path
        fi

        # remove file if exist
        if [ -f $path ]; then
            rm -f $path
            echo removed file: $path
        fi
    done
}

function zip() {
    local source=$1
    local target=$2
    ditto -c -k --sequesterRsrc --keepParent $source $target
    if [ $? -ne 0 ]; then
        echo create zip failed!
        exit -1
    fi
}

function tarxz() {
    local source=$1
    local target=$2
    tar -C $export_path -cJf $target $source
    if [ $? -ne 0 ]; then
        echo create tar.xz failed!
        exit -1
    fi
}

function build() {
    cd $app_dir                          && \
    xcrun xcodebuild build                  \
        -skipPackagePluginValidation        \
        -skipMacroValidation                \
        -quiet                              \
        -scheme $scheme                     \
        -configuration $configuration       \
        -destination "$destination"         \
        -derivedDataPath $derived_data_path
}

function sparkle() {
    cd $app_dir
    local app_info_plist="$app_dir/$(xcrun xcodebuild -showBuildSettings | grep -e ".plist" | grep -e INFOPLIST_FILE | cut -d '=' -f 2 | xargs)"
    if [ ! -f $app_info_plist ]; then
        echo info.plist file not found
        exit -1
    fi

    sparkle_SUFeedURL=$($plistBuddyBin -c "Print SUFeedURL" "$app_info_plist")
    sparkle_appcast_xml_URL=${git_url%%.git}
    sparkle_appcast_xml_URL=${sparkle_appcast_xml_URL/github.com/raw.githubusercontent.com}
    sparkle_appcast_xml_URL=${sparkle_appcast_xml_URL}/main${product_dir##${git_repo_dir}}/appcast.xml
    if [ "$sparkle_SUFeedURL" != "$sparkle_appcast_xml_URL" ]; then
        $plistBuddyBin -c "Set :SUFeedURL $sparkle_appcast_xml_URL" "$app_info_plist"
        echo update appcast xml url: $sparkle_appcast_xml_URL
    fi

    sparkle_SUPublicEDKey=$($plistBuddyBin -c "Print SUPublicEDKey" "$app_info_plist")
    sparkle_generate_keys=$sparkle_bin/generate_keys
    sparkle_local_public_key=$($sparkle_generate_keys -p)
    if [ $? -ne 0 ]; then
        unset sparkle_local_public_key
    fi
    if [ -z "$sparkle_local_public_key" ]; then
        sparkle_generate_public_key=$($sparkle_generate_keys | grep -o "<string>.*</string>")
        sparkle_generate_public_key=${sparkle_generate_public_key##<string>}
        sparkle_generate_public_key=${sparkle_generate_public_key%%</string>}
        # save private key into local keychain
        sparkle_generate_private_key=sparkle_private_key
        if [ -f $sparkle_generate_private_key ]; then
            rm -f $sparkle_generate_private_key
        fi
        $sparkle_generate_keys -x $sparkle_generate_private_key
        $sparkle_generate_keys -f $sparkle_generate_private_key
        # record new generated public key
        sparkle_local_public_key=$sparkle_generate_public_key
    fi

    # update SUPublicEDKey if changed
    if [ "$sparkle_SUPublicEDKey" != "$sparkle_local_public_key" ]; then
        echo old: $sparkle_SUPublicEDKey
        echo new: $sparkle_local_public_key
        # update SUPublicEDKey value with generated new public key
        $plistBuddyBin -c "Set :SUPublicEDKey $sparkle_local_public_key" "$app_info_plist"
    fi
}

function archive() {
    cd $app_dir                          && \
    xcrun xcodebuild archive                \
        -skipPackagePluginValidation        \
        -skipMacroValidation                \
        -quiet                              \
        -scheme $scheme                     \
        -configuration $configuration       \
        -destination "$destination"         \
        -derivedDataPath $derived_data_path \
        -archivePath $archive_path
}

function write_export_options_plist() {
cat > $export_options_plist <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
    <dict>
        <key>teamID</key>
        <string>${team_id}</string>
        <key>method</key>
        <string>developer-id</string>
    </dict>
</plist>
EOF
}

function exportArchive() {
    xcrun xcodebuild                                \
        -exportArchive                              \
        -archivePath $archive_path                  \
        -exportOptionsPlist $export_options_plist   \
        -exportPath $export_path
}

function notarize() {
    zip $export_app $export_app_zip              && \
    xcrun notarytool submit                         \
        --apple-id $apple_id                        \
        --password $app_specific_password           \
        --team-id $team_id                          \
        --wait                                      \
        --timeout $notary_timeout_duration          \
        $export_app_zip                          && \
    xcrun stapler staple $export_app             && \
    spctl -a -t exec -vv $export_app             && \
    remove $export_app_zip
}

function distribute() {
    app_dist_file_ext=$1

    version=$($plistBuddyBin -c "Print CFBundleVersion" "$app_info_plist")
    short_version=$($plistBuddyBin -c "Print CFBundleShortVersionString" "$app_info_plist")
    date=$(date +%Y%m%d_%H%M%S)
    app_dist_file="${product_dir}/${scheme}_${short_version}_${version}_${date}.${app_dist_file_ext}"

    case $app_dist_file_ext in
        "tar.xz")
            tarxz $(basename $export_app) $app_dist_file
            ;;
        "zip")
            zip $export_app $app_dist_file
            ;;
        *)
            echo unsupportted file type
            ;;
    esac

    if [ $? -ne 0 ]; then
        echo create dist file with staple ticket failed!
        exit -1
    fi

    echo dist file of app: $app_dist_file
}

function write_appcast_xml() {
    sparkle_generate_appcast=$sparkle_bin/generate_appcast
    $sparkle_generate_appcast $product_dir

    # change url
    app_dist_file_name=$(basename $app_dist_file)
    url_pattern="https://.*${app_dist_file_name//./\\.}"
    target_url=${git_url%%.git}/releases/download/${short_version}/${app_dist_file_name}
    target_url=${target_url//./\\.}
    # echo pattern: $url_pattern
    # echo target: $target_url
    sed -i'' -e  "s|${url_pattern}|${target_url}|" $product_dir/appcast.xml
}

function clean_products() {
    remove $product_dir/*.zip $product_dir/*.tar.xz
}

function cleanup() {
    remove $app_dir/*.zip       \
        *.plist *.log           \
        $build_dir $derived_data_path $export_app
}

cleanup && clean_products     && \
build && sparkle && archive   && \
write_export_options_plist    && \
exportArchive && notarize     && \
sparkle && distribute "zip"   && \
write_appcast_xml && cleanup  && \
echo "✅ App Generated"

# Publish Documentation to Github Pages
function build_doc() {
    echo "Building documentation..."
    xcodebuild docbuild             \
        -quiet                      \
        -scheme ${scheme}           \
        -destination ${destination} \
        -derivedDataPath ${derived_data_path}
}

function convert_doc() {
    echo "Converting documentation..."
    DOCCARCHIVE_PATH=$(find ${derived_data_path} -type d -name "${scheme}.doccarchive")
    xcrun docc process-archive transform-for-static-hosting \
      "$DOCCARCHIVE_PATH"                                   \
      --output-path ${docs_dir}                             \
      --hosting-base-path /${git_repo_name}                 \
      && rm -rf ${derived_data_path}
}

function prepare_index_page() {
    echo "Preparing GitHub Pages files..."
    lowercase_scheme=$(echo "$scheme" | tr '[:upper:]' '[:lower:]')
    touch ${docs_dir}/.nojekyll
    cat > ${docs_dir}/index.html <<EOF
    <!DOCTYPE html>
    <html>
    <head>
        <meta http-equiv="refresh" content="0; url=/${git_repo_name}/documentation/${lowercase_scheme}">
    </head>
    <body>
        <p>Redirecting to <a href="/${git_repo_name}/documentation/${lowercase_scheme}">documentation</a>...</p>
    </body>
    </html>
EOF
}

function push_to_gh_pages() {
    echo "Publishing to GitHub Pages..."

    # 检查分支是否存在
    if git show-ref --quiet refs/heads/${gh_pages_branch}; then
      # 分支存在，检出到临时目录
      git worktree add --force ${gh_pages_branch} ${gh_pages_branch}
    else
      # 分支不存在，创建孤儿分支
      current_branch_name_bak=$(git branch --show-current)
      git checkout --orphan ${gh_pages_branch}
      git rm -rf .
      git commit --allow-empty -m "Initial gh-pages commit"
      git push origin -u ${gh_pages_branch}
      git checkout ${current_branch_name_bak} # 回到之前的分支
      git worktree add ${gh_pages_branch} ${gh_pages_branch}
    fi

    # 复制文档
    rsync -av --delete --exclude='.git' ${docs_dir} ${gh_pages_branch}

    # 提交更改
    cd ${gh_pages_branch}
    git add --all
    git commit -m "Update documentation $(date +'%Y-%m-%d %H:%M:%S')"
    git push --force origin ${gh_pages_branch}
    cd -
}

function cleanup_for_doc() {
    git worktree remove ${gh_pages_branch}
    rm -rf ${docs_dir} ${gh_pages_branch}
}

cd $app_dir         && \
build_doc           && \
convert_doc         && \
prepare_index_page  && \
push_to_gh_pages    && \
cleanup_for_doc     && \
echo "✅ Documentation published to GitHub Pages branch!"