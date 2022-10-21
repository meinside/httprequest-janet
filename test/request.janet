(use ../src/init)

(import spork/json)

(def header-key-for-test "test-header")
(def header-value-for-test "http request test")
(def filepath-for-test (string (os/cwd) "/src/init.janet"))
(def param-for-test {:a "A"
                     :b -42
                     :c [1 2 3 4]
                     :d {:x 10 :y "Y" :z :z}})

# HTTP GET
(let [response (get "https://postman-echo.com/get"
                    {header-key-for-test header-value-for-test}
                    param-for-test)
      status (response :status)
      body (json/decode (response :body))
      headers (body "headers")
      args (body "args")]
    (assert (= 200 status))

    #(pp body)

    (assert (= (headers header-key-for-test) header-value-for-test))
    (assert (pos? (length args))))

# HTTP DELETE
(let [response (delete "https://postman-echo.com/delete"
                       {header-key-for-test header-value-for-test}
                       param-for-test)
      status (response :status)
      body (json/decode (response :body))
      headers (body "headers")
      args (body "args")]
    (assert (= 200 status))

    #(pp body)

    (assert (= (headers header-key-for-test) header-value-for-test))
    (assert (pos? (length args))))

# HTTP POST (application/x-www-form-urlencoded)
(let [response (post "https://postman-echo.com/post"
                     {header-key-for-test header-value-for-test}
                     param-for-test)
      status (response :status)
      body (json/decode (response :body))
      headers (body "headers")
      form (body "form")]
    (assert (= 200 status))

    #(pp body)

    (assert (= (headers header-key-for-test) header-value-for-test))
    (assert (pos? (length form))))

# HTTP POST (application/json)
(let [response (post<-json "https://postman-echo.com/post"
                           {header-key-for-test header-value-for-test}
                           param-for-test)
      status (response :status)
      body (json/decode (response :body))
      headers (body "headers")
      data (body "data")]
    (assert (= 200 status))

    #(pp body)

    (assert (= (headers header-key-for-test) header-value-for-test))
    (assert (pos? (length data))))

# HTTP POST (multipart/form-data)
(let [file (filepath->param filepath-for-test)]
    (assert file)

    (let [response (post "https://postman-echo.com/post"
                         {:test-header "http request test"}
                         (merge param-for-test
                                {:file file}))
          status (response :status)
          body (json/decode (response :body))
          headers (body "headers")
          files (body "files")]
        (assert (= 200 status))

        #(pp body)

        (assert (= (headers header-key-for-test) header-value-for-test))
        (assert (pos? (length files)))))

# HTTP PUT (application/x-www-form-urlencoded)
(let [response (put "https://postman-echo.com/put"
                    {header-key-for-test header-value-for-test}
                    param-for-test)
      status (response :status)
      body (json/decode (response :body))
      headers (body "headers")
      form (body "form")]
    (assert (= 200 status))

    #(pp body)

    (assert (= (headers header-key-for-test) header-value-for-test))
    (assert (pos? (length form))))

# HTTP PUT (application/json)
(let [response (put<-json "https://postman-echo.com/put"
                          {header-key-for-test header-value-for-test}
                          param-for-test)
      status (response :status)
      body (json/decode (response :body))
      headers (body "headers")
      data (body "data")]
    (assert (= 200 status))

    #(pp body)

    (assert (= (headers header-key-for-test) header-value-for-test))
    (assert (pos? (length data))))

# 404 error
(let [response (get "https://postman-echo.com/no-such-url"
                    {header-key-for-test header-value-for-test}
                    param-for-test)
      status (response :status)
      body (response :body)]
    #(pp body)

    (assert (= 404 status)))

# other errors (should be handled with `try`)
(try
  (do
    (let [response (get "malformed-url"
                        {header-key-for-test header-value-for-test}
                        param-for-test)]
      #(pp response)

      (assert false)))
  ([err] (do
           (print (string/format "failed to handle malformed url: %s" (string err)))

           (assert true))))
