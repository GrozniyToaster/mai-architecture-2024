!const INTERNAL_SYNC_CALL "http:80, grpc:80"
!const EXTERNAL_SYNC_CALL "https:443"
!const DEFAULT_OS "Ubuntu 22.04.4 LTS"

workspace {
    name "Пример для лабораторной работы 01"  
    !docs documentation
    !adrs decisions

    !identifiers hierarchical

    model {
        user = person "User"
        moderator = person "Moderator"
        cdn = softwareSystem "CDN" "Content Delivery Network" ""
        social_network = softwareSystem "X-Tagram" "Социальна сеть" {
            native_app = container "NativeApplication" "Application for user to communicate with sistem" {
                component "WebSinglePageApplication" "javascript"
                component "Android" "flutter"
                component "IOS" "flutter"
                component "MacOS" "flutter"
                component "Linux" "flutter"
                component "Windows" "flutter"
            }
            web_server = container "WebApplication" "Delivers the static content and the SinglePageApplication"

            api_application = container "ApiApplication" "Provides functionality via API." "python, FastAPI" {    
                backend = component "backend" "All buisiness logic"
                
            }

            realtime_events_provider = container "RealtimeEventProvider" "Provede keep alive connections with realtime events" "centrifugo" {
                notifications_provider = component "Notifications"
                new_messages_provider = component "Messaging component"
            }

            database = container "Database" "Stores user data." "YDB, postgresql" {}

            search_engine = container "SearchEngine" "Stores index for fast serch user" {
                search_api = component SearchEngineApi "" "python, FastApi" 
                index = component "ElasticSearch"
            }

            adminka = container "Adminka" "Administration panel" "python, django" {}


            user -> native_app "Create account, posting, chatting, find users to chat" {
                properties {
                    send "name of operation, data for operation"
                    return "status of process, result of operation"
                }

            }
            user -> web_server "Vitit to get static and SinglePageApplication code" {
                properties {
                    return "javascript code to execute" 
                }
            }

            native_app -> cdn "get static content and upload users content" "${EXTERNAL_SYNC_CALL}" {
                properties {
                    send "id of content"
                    return "static content" 
                }
            }

            native_app ->  realtime_events_provider.notifications_provider "get notifications" "wss:443" {
                properties {
                    send "ping"
                    return "events" 
                }
            }

            native_app ->  realtime_events_provider.new_messages_provider "get new message in chat" "wss:443" {
                properties {
                    send "ping"
                    return "events" 
                }
            }

            native_app -> api_application "create account, get message history, send message to user, make post, get users page" "${EXTERNAL_SYNC_CALL}" {
                properties {
                    send "name of operation, data for operation"
                    return "status of process, result of operation"
                }
            }

            native_app -> search_engine "search users" "${EXTERNAL_SYNC_CALL}" {
                properties {
                    send "part of name or mask to serch"
                    return "most relevant users"
                }
            }

            search_engine.search_api -> search_engine.index "manupulate index" "tcp:9200" {
                properties {
                    send "name of operation, data for operation"
                    return "status of process, result of operation"
                }
            }

            api_application -> database "store user data" "SQL\tcp" {
                properties {
                    send "name of operation, data for operation"
                    return "status of process, result of operation"
                }
            }
            api_application -> search_engine.search_api "add or remove user from search index" "${INTERNAL_SYNC_CALL}" {
                properties {
                    send "name of operation, data for operation"
                    return "status of process, result of operation"
                }
            }
            
            api_application ->  realtime_events_provider.notifications_provider "post notifications" "${INTERNAL_SYNC_CALL}" {
                properties {
                    send "notifications"
                    return "result of operation" 
                }
            }

            api_application ->  realtime_events_provider.new_messages_provider "post new messages" "${INTERNAL_SYNC_CALL}" {
                properties {
                    send "notifications"
                    return "result of operation" 
                }
            }


            
            moderator -> adminka "moderate users posts" "${EXTERNAL_SYNC_CALL}" {
                properties {
                    send "name of operation, data for operation"
                    return "status of process, result of operation"
                }
            }
            adminka -> api_application "moderate users posts and data" "${INTERNAL_SYNC_CALL}" {
                properties {
                    send "name of operation, data for operation"
                    return "status of process, result of operation"
                }
            }
            adminka -> search_engine.search_api "excluder users from search" "${INTERNAL_SYNC_CALL}" {
                properties {
                    send "name of operation, data for operation"
                    return "status of process, result of operation"
                }
            }
        }
        
        production = deploymentEnvironment "Production" {
            internal = deploymentGroup "InternalApi"

            deploymentNode "WebApplicationServer" "" "Alpine Linux" "" "4" {
                deploymentNode "WebServer" "" "nginx" {
                    containerInstance social_network.web_server
                }
            }

            deploymentNode "NativeApp" "" "Web Browser, Android, IOS, MacOS, Windows, Linux" {
                containerInstance social_network.native_app
            }

            deploymentNode "ApiApplicationServer" "" "${DEFAULT_OS}" {
                infrastructureNode "loadbalancer" "" "envoy"
                infrastructureNode "cache proxy" "" "envoy"
                deploymentNode "ApiApplicationServerBackend" "" "" "" "4" {
                    containerInstance social_network.api_application 
                }
            }

            deploymentNode "RealtimeEventProviderServer" "" "${DEFAULT_OS}" {
                infrastructureNode "loadbalanser" "" "envoy"
                deploymentNode "Cetrifugo" "" "" "" "4" {
                    containerInstance social_network.realtime_events_provider 
                }
            }

            deploymentNode "Database" {
                master = deploymentNode "Master" "" "${DEFAULT_OS}" {
                    containerInstance social_network.database 
                }

                slave = deploymentNode "Slave" "" "${DEFAULT_OS}" {
                    containerInstance social_network.database 
                }

                master -> slave "replicate"
            }

            deploymentNode "SearchEngine" {
                api = deploymentNode "Api" "" "${DEFAULT_OS}" "" {
                    infrastructureNode "loadbalancer" "" "envoy" 
                    deploymentNode "Backend" "" "${DEFAULT_OS}" "" "4" {
                        containerInstance social_network.search_engine
                    }
                }
                index = deploymentNode "Index" "" "${DEFAULT_OS} Elasticsearch" {
                    containerInstance social_network.search_engine internal
                }

                api -> index "Manipulate"
            }
            
            deploymentNode "Adminka" "" "${DEFAULT_OS}" "" "2" {
                containerInstance social_network.adminka
            }
        }
        

    }   
    views {
        themes default

        systemContext social_network "ContextView" { 
            include *
            autoLayout 
        }

        container social_network "ContainerView" { 
            include *
            autoLayout 
        }

        component social_network.realtime_events_provider "RealtimeEventsProviderContainerView" {
            include *
            autoLayout lr
        }

        component social_network.search_engine "SearchEngineContainerView" {
            include *
            autoLayout lr
        }

        deployment * production "DeploymentView" {
            include *
            autolayout
        }

        dynamic social_network {
            title "create user"

            user -> social_network.native_app "Request create user with name and other data"
            social_network.native_app -> social_network.api_application "Request create user with name and other data"
            social_network.api_application -> social_network.search_engine "Check user with spicified name does not exist"

            social_network.api_application -> social_network.database "Create user"
            social_network.api_application -> social_network.search_engine "Add user to index"

            autoLayout lr
        }

        dynamic social_network {
            title "search user by login or mask"

            user -> social_network.native_app "Seach uaser by login or mask"
            social_network.native_app -> social_network.search_engine "Query statement"

            autoLayout lr
        }

        dynamic social_network {
            title "send message to user"

            user -> social_network.native_app "send message to user"
            social_network.native_app -> social_network.api_application "create mesage in chat"
            social_network.api_application -> social_network.database "create mesage in chat"
            social_network.api_application -> social_network.realtime_events_provider "create event on new message"


            autoLayout lr
        }


    }
}