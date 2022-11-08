# httprequest

HTTP Request helper library for [Janet](https://janet-lang.org/).

There are many HTTP libraries, but most of them do not proivde methods for building request bodies.

So I made this helper.

## Install

In your `project.janet` file, add:

```clojure
{:dependencies ["https://github.com/meinside/httprequest-janet"]}
```

## Dependencies

It depends on:

* [janet-uri](https://github.com/andrewchambers/janet-uri) for `urlencode`,
* [joy-framework/http](https://github.com/joy-framework/http) for sending http requests, and
* [spork](https://github.com/janet-lang/spork) for JSON decoding.

and `libcurl4-openssl-dev`, so you need to:

```bash
$ sudo apt install libcurl4-openssl-dev
```

## Usage

Do HTTP methods with:

```clojure
(import httprequest :as r)
  
(r/get "https://postman-echo.com/get"
       {:header-key1 :header-value1
        :header-key2 :header-value2}
       {:query-key1 "some value"
        :query-key2 -42}))

(let [file (r/filepath->param "/home/ubuntu/data/test.png")]
  (r/post "https://postman-echo.com/post"
          {:header-key1 :header-value1
           :header-key2 :header-value2}
          {:file file
           :form-key1 "some value"
           :form-key2 -42}))

(r/post<-json "https://postman-echo.com/post"
              {:header-key1 :header-value1
               :header-key2 :header-value2}
              {:form-key1 "some value"
               :form-key2 -42})
```

or create HTTP requests and execute/enqueue them:

```clojure
(let [req (r/new-request :get "https://postman-echo.com/get")
      response (:execute req)]
    (pp response))

(let [queue (r/new-queue)
      req1 (r/new-request :post "https://postman-echo.com/post")
      req2 (r/new-request :put "https://postman-echo.com/put")]
    (:enqueue queue req1
                    (fn [res]
                      (pp res))
                    (fn [res]
                      (= 200 (res :status)))
                    (fn [err]
                      (pp err))
                    (fn [res]
                      (not= 200 (res :status))))
    (:enqueue queue req2
                    (fn [res]
                      (pp res)))

    (:close queue))
```

