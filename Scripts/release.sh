#!/usr/bin/env bash
#-*- coding: utf-8 -*-

# 脚本参数区
scheme=OrzMC
team_id=2N62934Y28
configuration=Release
destination="generic/platform=macOS"
gh_pages_branch="gh-pages"


apple_id="824219521@qq.com"
app_specific_password="bbgb-nzuk-trqz-uzax"
notary_timeout_duration="5m"

# git仓库信息获取
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

# 构建相关路径获取
derived_data_path="$git_repo_dir/DerivedData"
build_dir=$git_repo_dir/build
archive_path="$build_dir/$scheme.xcarchive"
app_dir=$git_repo_dir
docs_dir="${app_dir}/docs"
product_dir=$app_dir/products

# 打包相关配置
export_options_plist=$app_dir/exportOptions.plist
export_path=$app_dir
export_app=$export_path/$scheme.app
export_app_zip=$export_app.zip

plistBuddyBin=/usr/libexec/PlistBuddy
app_info_plist="$export_app/Contents/Info.plist"

sparkle_bin=$derived_data_path/SourcePackages/artifacts/sparkle/Sparkle/bin
appcast_xml=$product_dir/appcast.xml

# Publish App
function exit_if_error() {
    if [ $? -ne 0 ]; then
        if [ "$#" -gt 0 ]; then
            echo 🔴 $@
        fi
        exit -1
    fi
}

function exit_with_msg() {
    if [ "$#" -gt 0 ]; then
        echo 🔴 $@
        exit -1
    fi
}

function remove() {
    for path in $*
    do
        # remove dir if exist
        if [ -d $path ]; then
            rm -rf $path
            echo 📂 removed dir: $path
        fi

        # remove file if exist
        if [ -f $path ]; then
            rm -f $path
            echo 📄 removed file: $path
        fi
    done
}

function zip() {
    local source=$1
    local target=$2
    ditto -c -k --sequesterRsrc --keepParent $source $target
    exit_if_error create zip failed!
}

function tarxz() {
    local source=$1
    local target=$2
    tar -C $export_path -cJf $target $source
    exit_if_error create tar.xz failed!
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
    exit_if_error build $scheme on $destination failed!
}

function sparkle() {
    cd $app_dir
    local app_info_plist="$app_dir/$(xcrun xcodebuild -showBuildSettings | grep -e ".plist" | grep -e INFOPLIST_FILE | cut -d '=' -f 2 | xargs)"
    if [ ! -f $app_info_plist ]; then
        exit_with_msg info.plist file not found
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
            remove $sparkle_generate_private_key
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
    exit_if_error archive $scheme on $destination failed
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
    exit_if_error export archive failed
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
    exit_if_error notarize failed
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
            echo create tar.xz file: $app_dist_file
            ;;
        "zip")
            zip $export_app $app_dist_file
            echo create zip file: $app_dist_file
            ;;
        *)
            echo unsupportted file type
            ;;
    esac
    exit_if_error create dist file with staple ticket failed!
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
    sed -i'' -e  "s|${url_pattern}|${target_url}|" $appcast_xml
    exit_if_error write appcast.xml failed
}

function clean_products() {
    remove $product_dir/*.zip $product_dir/*.tar.xz
}

function cleanup() {
    remove $app_dir/*.zip       \
        *.plist *.log           \
        $build_dir              \
        $derived_data_path      \
        $export_app
}

function upload_app_to_release() {
    # 设置变量
    value="$(echo "cHJlZml4X2docF9kUEN1NE54dGp0Nlh5dkg1cHlvOTUxMUthRFRwTmkyWkpqNGkK" | base64 -d)"
    KEY=${value#prefix_}
    REPO="${git_user_repo_name}"
    TAG="${short_version}"

    if git ls-remote --tags origin refs/tags/"$TAG" | grep -q "$TAG"; then
        echo "tag: $TAG exist"
    else
        git tag $TAG && git push origin $TAG
        exit_if_error create tag: $TAG failed
    fi

    release_id=$(curl -s https://api.github.com/repos/$REPO/releases | jq --arg tag $TAG '.[] | select(.tag_name == $tag) | .id')
    if [ -z "$release_id" ]; then
        echo create release for $TAG
        release_id=$(curl -X POST \
        -H "Authorization: token $KEY" \
        -H "Content-Type: application/json" \
        -d '{"tag_name": "'$TAG'", "name": "'$TAG'", "body": "Release notes"}' \
        https://api.github.com/repos/$REPO/releases | jq -r '.id')
    fi
    # 上传文件
    echo upload zip file: $app_dist_file
    response=$(curl -X POST \
        -H "Authorization: token $KEY" \
        -H "Content-Type: application/zip" \
        --data-binary @"$app_dist_file" \
        "https://uploads.github.com/repos/$REPO/releases/$release_id/assets?name=$app_dist_file_name")

    # 上传成功后，删除本地文件，并推送更新后的appcast.xml文件到远端
    if echo "$response" | jq -e . >/dev/null 2>&1; then
        if [ "$(echo "$response" | jq -r '.state')" = "uploaded" ]; then
            echo "App上传成功"
            if git ls-files -m | grep -q "$(basename $appcast_xml)"; then
                git add $appcast_xml
                git commit -m "updated appcast.xml for ${app_dist_file_name}"
                git push origin
                exit_if_error update appcast.xml failed 
            fi
        else
            exit_with_msg "App 上传失败"
        fi
    else
        exit_with_msg "App 上传失败"
    fi
}

function release_app() {
    cleanup                       && \
    clean_products                && \
    build && sparkle && archive   && \
    write_export_options_plist    && \
    exportArchive && notarize     && \
    sparkle && distribute "zip"   && \
    write_appcast_xml             && \
    upload_app_to_release         && \
    clean_products                && \
    cleanup                       && \
    echo "✅ App Published"
}

# Publish Documentation to Github Pages
function build_doc() {
    echo "Building documentation..."
    xcrun xcodebuild docbuild       \
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
      && remove ${derived_data_path}
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
    rsync -a --delete --exclude='.git' ${docs_dir} ${gh_pages_branch}

    # 提交更改
    cd ${gh_pages_branch}
    git add $(basename ${docs_dir})
    git commit -m "Update documentation $(date +'%Y-%m-%d %H:%M:%S')"
    git push --force origin ${gh_pages_branch}
    cd -
    # 移除worktree目录
    git worktree remove ${gh_pages_branch}
}

function cleanup_for_doc() {
    remove ${docs_dir} ${gh_pages_branch}
}


function release_doc() {
    cd $app_dir         && \
    cleanup_for_doc     && \
    build_doc           && \
    convert_doc         && \
    prepare_index_page  && \
    push_to_gh_pages    && \
    cleanup_for_doc     && \
    echo "✅ Documentation published to GitHub Pages branch!"
}

function print_usage() {
    echo "Usage: release.sh <[doc|app|all]>"
    echo
    echo "  doc - release doc only"
    echo "  app - release app only"
    echo "  all - release app & doc"
    echo 
    echo "notice: 'release.sh' with no argument is equal to 'release.sh all'"
}

function release() {
    case "$1" in
    app)
        echo Release App Only
        release_app
    ;;
    doc)
        echo Release Doc Only
        release_doc
    ;;
    all)
        echo "Release App & Doc"
        release_app && release_doc
    ;;
    *)
        print_usage
    ;;
    esac
}



function main() {
    if [ $# -eq 0 ]; then
        release all
    else
        release $@
    fi
}

main $@