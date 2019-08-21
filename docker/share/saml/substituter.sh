#!/bin/sh
set -e

if [[ $REPO_HOST == "" ]]; then
   REPO_HOST=localhost
fi

if [[ $REPO_PORT == "" ]]; then
   REPO_PORT=8080
fi

echo "Replace 'REPO_HOST' with '$REPO_HOST' and 'REPO_PORT' with '$REPO_PORT'"

sed -i -e 's/REPO_HOST:REPO_PORT/'"$REPO_HOST:$REPO_PORT"'/g' /usr/local/tomcat/shared/classes/alfresco/web-extension/share-config-custom.xml

echo "NEW -csrf.filter.referer is '$CSRF_FILTER_REFERER'"
echo "NEW -csrf.filter.origin is '$CSRF_FILTER_ORIGIN'"

if [ $CSRF_FILTER_REFERER != "" ] && [   $CSRF_FILTER_ORIGIN != "" ]; then
# set CSRFPolicy to true and set both properties referer and origin
   #sed -i -e "s|<config evaluator=\"string-compare\" condition=\"CSRFPolicy\" replace=\"false\">|<config evaluator=\"string-compare\" condition=\"CSRFPolicy\" replace=\"true\">|" /usr/local/tomcat/shared/classes/alfresco/web-extension/share-config-custom.xml
   #sed -i -e "s|<referer><\/referer>|<referer>$CSRF_FILTER_REFERER<\/referer>|" /usr/local/tomcat/shared/classes/alfresco/web-extension/share-config-custom.xml
   #sed -i -e "s|<origin><\/origin>|<origin>$CSRF_FILTER_ORIGIN<\/origin>|" /usr/local/tomcat/shared/classes/alfresco/web-extension/share-config-custom.xml

   # First delete the last tag
sed -i '/^[ \t]*<\/alfresco-config>/d' /usr/local/tomcat/shared/classes/alfresco/web-extension/share-config-custom.xml

# Then add the config with the last tag
echo -e "<config evaluator=\"string-compare\" condition=\"CSRFPolicy\" replace=\"true\">\n
        <filter>\n
            <rule>\n
                <request>\n
                    <method>GET</method>\n
                    <path>/res/.*</path>\n
                </request>\n
            </rule>\n
            <rule>\n
                <request>\n
                    <method>POST</method>\n
                    <path>/page/saml-authnresponse|/page/saml-logoutresponse|/page/saml-logoutrequest</path>\n
                </request>\n
            </rule>\n
            <rule>\n
                <request>\n
                    <path>/proxy/alfresco/remoteadm/.*</path>\n
                </request>\n
                <action name=\"throwError\">\n
                    <param name=\"message\">It is not allowed to access this url from your browser</param>\n
                </action>\n
            </rule>\n
            <rule>\n
                <request>\n
                    <method>POST</method>\n
                    <path>/proxy/alfresco/api/publishing/channels/.+</path>\n
                </request>\n
                <action name=\"assertReferer\">\n
                    <param name=\"referer\">$CSRF_FILTER_REFERER</param>\n
                </action>\n
                <action name=\"assertOrigin\">\n
                    <param name=\"origin\">$CSRF_FILTER_ORIGIN</param>\n
                </action>\n
            </rule>\n
            <rule>\n
                <request>\n
                    <method>POST</method>\n
                    <path>/page/caches/dependency/clear|/page/index|/page/surfBugStatus|/page/modules/deploy|/page/modules/module|/page/api/javascript/debugger|/page/console</path>\n
                </request>\n
                <action name=\"assertReferer\">\n
                    <param name=\"referer\">$CSRF_FILTER_REFERER</param>\n
                </action>\n
                <action name=\"assertOrigin\">\n
                    <param name=\"origin\">$CSRF_FILTER_ORIGIN</param>\n
                </action>\n
            </rule>\n
            <rule>\n
                <request>\n
                    <method>POST</method>\n
                    <path>/page/dologin(\?.+)?|/page/site/[^/]+/start-workflow|/page/start-workflow|/page/context/[^/]+/start-workflow</path>\n
                </request>\n
                <action name=\"assertReferer\">\n
                    <param name=\"referer\">$CSRF_FILTER_REFERER</param>\n
                </action>\n
                <action name=\"assertOrigin\">\n
                    <param name=\"origin\">$CSRF_FILTER_ORIGIN</param>\n
                </action>\n
            </rule>\n
            <rule>\n
                <request>\n
                    <method>POST</method>\n
                    <path>/page/dologout(\?.+)?</path>\n
                </request>\n
                <action name=\"assertReferer\">\n
                    <param name=\"referer\">$CSRF_FILTER_REFERER</param>\n
                </action>\n
                <action name=\"assertOrigin\">\n
                    <param name=\"origin\">$CSRF_FILTER_ORIGIN</param>\n
                </action>\n
                <action name=\"clearToken\">\n
                    <param name=\"session\">{token}</param>\n
                    <param name=\"cookie\">{token}</param>\n
                </action>\n
            </rule>\n
            <rule>\n
                <request>\n
                    <session>\n
                        <attribute name=\"_alf_USER_ID\">.+</attribute>\n
                        <attribute name=\"{token}\"/>\n
                    </session>\n
                </request>\n
                <action name=\"generateToken\">\n
                    <param name=\"session\">{token}</param>\n
                    <param name=\"cookie\">{token}</param>\n
                </action>\n
            </rule>\n
            <rule>\n
                <request>\n
                    <method>GET</method>\n
                    <path>/page/.*</path>\n
                    <session>\n
                        <attribute name=\"_alf_USER_ID\">.+</attribute>\n
                        <attribute name=\"{token}\">.+</attribute>\n
                    </session>\n
                </request>\n
                <action name=\"generateToken\">\n
                    <param name=\"session\">{token}</param>\n
                    <param name=\"cookie\">{token}</param>\n
                </action>\n
            </rule>\n
            <rule>\n
                <request>\n
                    <method>POST</method>\n
                    <header name=\"Content-Type\">multipart/.+</header>\n
                    <session>\n
                        <attribute name=\"_alf_USER_ID\">.+</attribute>\n
                    </session>\n
                </request>\n
                <action name=\"assertToken\">\n
                    <param name=\"session\">{token}</param>\n
                    <param name=\"parameter\">{token}</param>\n
                </action>\n
                <action name=\"assertReferer\">\n
                    <param name=\"referer\">$CSRF_FILTER_REFERER</param>\n
                </action>\n
                <action name=\"assertOrigin\">\n
                    <param name=\"origin\">$CSRF_FILTER_ORIGIN</param>\n
                </action>\n
            </rule>\n
            <rule>\n
                <request>\n
                    <method>POST|PUT|DELETE</method>\n
                    <session>\n
                        <attribute name=\"_alf_USER_ID\">.+</attribute>\n
                    </session>\n
                </request>\n
                <action name=\"assertToken\">\n
                    <param name=\"session\">{token}</param>\n
                    <param name=\"header\">{token}</param>\n
                </action>\n
                <action name=\"assertReferer\">\n
                    <param name=\"referer\">$CSRF_FILTER_REFERER</param>\n
                </action>\n
                <action name=\"assertOrigin\">\n
                    <param name=\"origin\">$CSRF_FILTER_ORIGIN</param>\n
                </action>\n
            </rule>\n
        </filter>\n
    </config>\n
</alfresco-config>\n
" >> /usr/local/tomcat/shared/classes/alfresco/web-extension/share-config-custom.xml
   
else
# set CSRFPolicy to false and leave empty the properties referer and origin
   sed -i -e "s|<config evaluator=\"string-compare\" condition=\"CSRFPolicy\" replace=\"false\">|<config evaluator=\"string-compare\" condition=\"CSRFPolicy\" replace=\"false\">|" /usr/local/tomcat/shared/classes/alfresco/web-extension/share-config-custom.xml
   sed -i -e "s|<referer><\/referer>|<referer><\/referer>|" /usr/local/tomcat/shared/classes/alfresco/web-extension/share-config-custom.xml
   sed -i -e "s|<origin><\/origin>|<origin><\/origin>|" /usr/local/tomcat/shared/classes/alfresco/web-extension/share-config-custom.xml
fi

bash -c "$@"

