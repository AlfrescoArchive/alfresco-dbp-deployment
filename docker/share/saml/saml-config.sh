#!/bin/bash

set -e

SHARE_CONFIG_CUSTOM='/usr/local/tomcat/shared/classes/alfresco/web-extension/share-config-custom.xml'

echo "Configuring ${SHARE_CONFIG_CUSTOM} with SAML settings."

# First delete the last tag
sed -i '/^[ \t]*<\/alfresco-config>/d' "${SHARE_CONFIG_CUSTOM}"

# Then add the config with the last tag
# Note:
# the 'CSRF_FILTER_REFERER' and 'CSRF_FILTER_ORIGIN' variables will be replaced with appropriate values by the base image at runtime.
echo -e "<config evaluator=\"string-compare\" condition=\"CSRFPolicy\" replace=\"true\">
        <filter>
            <rule>
                <request>
                    <method>GET</method>
                    <path>/res/.*</path>
                </request>
            </rule>
            <rule>
                <request>
                    <method>POST</method>
                    <path>/page/saml-authnresponse|/page/saml-logoutresponse|/page/saml-logoutrequest</path>
                </request>
            </rule>
            <rule>
                <request>
                    <path>/proxy/alfresco/remoteadm/.*</path>
                </request>
                <action name=\"throwError\">
                    <param name=\"message\">It is not allowed to access this url from your browser</param>
                </action>
            </rule>
            <rule>
                <request>
                    <method>POST</method>
                    <path>/proxy/alfresco/api/publishing/channels/.+</path>
                </request>
                <action name=\"assertReferer\">
                    <param name=\"referer\">$CSRF_FILTER_REFERER</param>
                </action>
                <action name=\"assertOrigin\">
                    <param name=\"origin\">$CSRF_FILTER_ORIGIN</param>
                </action>
            </rule>
            <rule>
                <request>
                    <method>POST</method>
                    <path>/page/caches/dependency/clear|/page/index|/page/surfBugStatus|/page/modules/deploy|/page/modules/module|/page/api/javascript/debugger|/page/console</path>
                </request>
                <action name=\"assertReferer\">
                    <param name=\"referer\">$CSRF_FILTER_REFERER</param>
                </action>
                <action name=\"assertOrigin\">
                    <param name=\"origin\">$CSRF_FILTER_ORIGIN</param>
                </action>
            </rule>
            <rule>
                <request>
                    <method>POST</method>
                    <path>/page/dologin(\?.+)?|/page/site/[^/]+/start-workflow|/page/start-workflow|/page/context/[^/]+/start-workflow</path>
                </request>
                <action name=\"assertReferer\">
                    <param name=\"referer\">$CSRF_FILTER_REFERER</param>
                </action>
                <action name=\"assertOrigin\">
                    <param name=\"origin\">$CSRF_FILTER_ORIGIN</param>
                </action>
            </rule>
            <rule>
                <request>
                    <method>POST</method>
                    <path>/page/dologout(\?.+)?</path>
                </request>
                <action name=\"assertReferer\">
                    <param name=\"referer\">$CSRF_FILTER_REFERER</param>
                </action>
                <action name=\"assertOrigin\">
                    <param name=\"origin\">$CSRF_FILTER_ORIGIN</param>
                </action>
                <action name=\"clearToken\">
                    <param name=\"session\">{token}</param>
                    <param name=\"cookie\">{token}</param>
                </action>
            </rule>
            <rule>
                <request>
                    <session>
                        <attribute name=\"_alf_USER_ID\">.+</attribute>
                        <attribute name=\"{token}\"/>
                    </session>
                </request>
                <action name=\"generateToken\">
                    <param name=\"session\">{token}</param>
                    <param name=\"cookie\">{token}</param>
                </action>
            </rule>
            <rule>
                <request>
                    <method>GET</method>
                    <path>/page/.*</path>
                    <session>
                        <attribute name=\"_alf_USER_ID\">.+</attribute>
                        <attribute name=\"{token}\">.+</attribute>
                    </session>
                </request>
                <action name=\"generateToken\">
                    <param name=\"session\">{token}</param>
                    <param name=\"cookie\">{token}</param>
                </action>
            </rule>
            <rule>
                <request>
                    <method>POST</method>
                    <header name=\"Content-Type\">multipart/.+</header>
                    <session>
                        <attribute name=\"_alf_USER_ID\">.+</attribute>
                    </session>
                </request>
                <action name=\"assertToken\">
                    <param name=\"session\">{token}</param>
                    <param name=\"parameter\">{token}</param>
                </action>
                <action name=\"assertReferer\">
                    <param name=\"referer\">$CSRF_FILTER_REFERER</param>
                </action>
                <action name=\"assertOrigin\">
                    <param name=\"origin\">$CSRF_FILTER_ORIGIN</param>
                </action>
            </rule>
            <rule>
                <request>
                    <method>POST|PUT|DELETE</method>
                    <session>
                        <attribute name=\"_alf_USER_ID\">.+</attribute>
                    </session>
                </request>
                <action name=\"assertToken\">
                    <param name=\"session\">{token}</param>
                    <param name=\"header\">{token}</param>
                </action>
                <action name=\"assertReferer\">
                    <param name=\"referer\">$CSRF_FILTER_REFERER</param>
                </action>
                <action name=\"assertOrigin\">
                    <param name=\"origin\">$CSRF_FILTER_ORIGIN</param>
                </action>
            </rule>
        </filter>
    </config>
</alfresco-config>
" >>"${SHARE_CONFIG_CUSTOM}"
