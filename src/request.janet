# src/request.janet
#
# Things for HTTP Request.
#
# created on : 2022.09.13.
# last update: 2023.08.03.

(import uri)
(import http)
(import spork/json)

(def- default-content-type "application/octet-stream")
(def- form-content-type "application/x-www-form-urlencoded")
(def- json-content-type "application/json;charset=utf-8")

# prototype for request
(def Request
  @{:method nil
    :url nil
    :headers {}
    :params {}

    :body? false
    :json? false

    # prototype functions
    :execute nil})

################################
# Parameter helper functions

(defn urlencode
  ``Returns the urlencoded string of the given value.
  ``
  [v]
  (uri/escape (string v)))

(defn urldecode
  ``Returns the urldecoded string of the given value.
  ``
  [v]
  (uri/unescape (string v)))

(defn file->param
  ``Returns a struct with a file handle and its filename for multipart request.

  Passed file handle will be closed automatically after HTTP request, so the returned struct should not be reused.
  ``
  [file filename &opt content-type]
  (default content-type default-content-type)
  {:handle file
   :filename filename
   :content-type content-type})

(defn filepath->param
  ``Returns a struct with a file handle and its filename for multipart request.

  File handle will be closed automatically after HTTP request, so the returned struct should not be reused.

  Returns nil when `file/open` fails with the passed filepath.
  ``
  [filepath &opt content-type]
  (default content-type default-content-type)
  (if-let [file (file/open filepath :r)
           filename (last (string/split "/" filepath))]
    (file->param file filename content-type)
    nil))

(defn- url->port
  ``Extracts a port number from given url. Falls back to 80.
  ``
  [url]
  (if-let [parsed (uri/parse url)]
    (if-let [port (parsed :port)]
      port
      (case (parsed :scheme)
        "http" 80
        "https" 443
        80))
    (if (string/has-prefix? "https" url)
      443
      80)))

(defn- file-param?
  ``Checks if given value is a file parameter.
  ``
  [v]
  (and
    (struct? v)
    (= :core/file (type (v :handle)))))

(defn has-file?
  ``Checks if given params include any file parameter value.
  ``
  [params]
  (not (empty? (filter file-param? (values params)))))

################################
# Misc. functions

(defn- arr?
  ``Returns if the given value is a tuple or array.
  ``
  [v]
  (or
    (tuple? v)
    (array? v)))

(defn- dict?
  ``Returns if the given value is a struct or table.
  ``
  [v]
  (or
    (struct? v)
    (table? v)))

(defn- arr->body
  ``Converts given tuple/array to a string for HTTP request body.
  ``
  [arr]
  (string/join (map urlencode (map string arr)) ","))

(defn- dict->body
  ``Converts given struct/table to a string for HTTP request body.
  ``
  [name dict]
  (string/join (map (fn [(k v)]
                      (string/format "%s[%s]=%s" (urlencode name) (urlencode k) (urlencode v)))
                    (pairs dict))
               "&"))

(defn- value->urlencoded
  ``Converts given parameter to urlencoded string.
  ``
  [v]
  (cond
    (arr? v) (arr->body v)
    (dict? v) (string/join (map (fn [(k v)]
                                  (string/format "%s=%s" (urlencode k) (urlencode v)))
                                (pairs v))
                           "&")
    (string v)))

(defn- params->body
  ``Converts given parameters to urlencoded request body.
  ``
  [dict]
  (string/join (map (fn [(k v)]
                      (cond
                        (arr? v) (string (urlencode k) "=" (arr->body v))
                        (dict? v) (dict->body k v)
                        (string (urlencode k) "=" (string v))))
                    (pairs dict))
               "&"))

(defn- params->multipart
  ``Converts given parameters to multipart request body.
  ``
  [dict boundary]
  (let [buf @""
        nl "\r\n"
        boundary (string "--" boundary)]
    (loop [(k v) :in (pairs dict)]
      (buffer/push-string buf boundary nl)
      (if (file-param? v)
        (do
          (let [file (v :handle)
                filename (v :filename)
                content-type (v :content-type)]
            (buffer/push-string buf (string/format "Content-Disposition: form-data; name=\"%s\"; filename=\"%s\"" k filename) nl)
            (buffer/push-string buf (string "Content-Type: " content-type) nl nl)
            (buffer/push-string buf (file/read file :all))

            # close the file here
            (file/close file)))
        (do
          (buffer/push-string buf (string/format "Content-Disposition: form-data; name=\"%s\"" k) nl nl)
          (buffer/push-string buf (value->urlencoded v))))
      (buffer/push-string buf nl))
    (buffer/push-string buf boundary "--" nl)
    buf))

(defn- params->json
  ``Converts given parameters to JSON string for request body.
  ``
  [dict]
  (json/encode dict))

(defn- method->string
  ``Converts method keyword to string.
  ``
  [method]
  (string/ascii-upper (string method)))

(defn- url+params->query
  ``Converts given URL and parameters to query string.
  ``
  [url params]
  (if (> (length params) 0)
    (string url "?" (params->body params))
    url))

(defn- request<-query
  ``Sends a HTTP request with query string.
  ``
  [method url headers params]
  (let [method (method->string method)
        url (url+params->query url params)
        port (url->port url)]
    (http/request method url {:headers headers
                              :port port})))

(defn- request<-body
  ``Sends a HTTP request with urlencoded or multipart body.
  ``
  [method url headers params &opt json?]
  (let [method (method->string method)
        multipart? (has-file? params)
        boundary (string "____boundary_" (os/time) "____")
        body (if multipart?
               (params->multipart params boundary)
               (if json?
                 (params->json params)
                 (params->body params)))
        headers (merge headers
                       {"Content-Type" (if multipart?
                                         (string/format "multipart/form-data; boundary=%s" boundary)
                                         (if json?
                                           json-content-type
                                           form-content-type))})
        port (url->port url)]
    (http/request method url {:headers headers
                              :body body
                              :port port})))

(defn- request
  ``Sends a HTTP request and returns the response body as a string.
  ``
  [method url headers params &named body? json?]
  (if body?
    (request<-body method url headers params json?)
    (request<-query method url headers params)))

################################
# HTTP method functions

(defn get
  ``Sends a HTTP GET request and returns the response.

  Call with `:body? true` for sending params as body,

  and `:json? true` for sending body in JSON format.
  ``
  [url headers params &named body? json?]
  (request :get url headers params :body? body?
                                   :json? json?))

(defn post
  ``Sends a HTTP POST request and returns the response.

  Call with `:json? true` for sending body in JSON format.
  ``
  [url headers params &named json?]
  (request :post url headers params :body? true
                                    :json? json?))

(defn post<-json
  ``Sends a HTTP POST request with JSON body and returns the response.
  ``
  [url headers params]
  (request :post url headers params :body? true
                                    :json? true))

(defn delete
  ``Sends a HTTP DELETE request and returns the response.

  Call with `:body? true` for sending params as body,

  and `:json? true` for sending body in JSON format.
  ``
  [url headers params &named body? json?]
  (request :delete url headers params :body? body?
                                      :json? json?))

(defn put
  ``Sends a HTTP PUT request and returns the response.

  Call with `:json? true` for sending body in JSON format.
  ``
  [url headers params &named json?]
  (request :put url headers params :body? true
                                   :json? json?))

(defn put<-json
  ``Sends a HTTP PUT request with JSON body and returns the response.
  ``
  [url headers params]
  (request :put url headers params :body? true
                                   :json? true))

(defn patch
  ``Sends a HTTP PATCH request and returns the response.

  Call with `:json? true` for sending body in JSON format.
  ``
  [url headers params &named json?]
  (request :patch url headers params :body? true
                                     :json? json?))

(defn patch<-json
  ``Sends a HTTP PATCH request with JSON body and returns the response.
  ``
  [url headers params]
  (request :patch url headers params :body? true
                                     :json? true))


################################
# Helper functions

(defn new-request
  ``Creates and returns a new request.
  ``
  [method url &opt headers params body? json?]

  (default headers {})
  (default params {})
  (default body? (index-of method [:post :put :patch])) # FIXME: may not be a reasonable default value
  (default json? false)

  (table/setproto @{:method method
                    :url url
                    :headers headers
                    :params params
                    :body? body?
                    :json? json?

                    :execute (fn [self]
                               (request (self :method)
                                        (self :url)
                                        (self :headers)
                                        (self :params)
                                        :body? (self :body?)
                                        :json? (self :json?)))}
                  Request))

