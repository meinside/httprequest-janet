# test/queue.janet
#
# last update: 2022.11.03.

(use ../src/request)
(use ../src/queue)

(import spork/json)

(def- max-retries 3)

# processing of requests will be executed in the sequence they were enqueued, no matter how long each request takes.
(let [queue (new-queue max-retries)
      request (new-request :get "https://postman-echo.com/get")
      ch (ev/thread-chan)]

  (ev/spawn-thread
    (do
      # retry on error
      (assert (:enqueue queue
                        (new-request :get "https://postman-echo.com/status/503")
                        (fn [res]
                          (assert (= 503 (res :status)))

                          (ev/give ch 0))
                        (fn [res]
                          # success when 200 (will fail on purpose)
                          (= 200 (res :status)))
                        (fn [err]
                          (assert false "will not reach here"))
                        (fn [res]
                          # retry on 503 error
                          (= 503 (res :status)))))
      # error but not retry
      (assert (:enqueue queue
                        (new-request :get "https://postman-echo.com/status/404")
                        (fn [res]
                          (assert (= 404 (res :status)))

                          (ev/give ch 1))
                        (fn [res]
                          # success when 200 (will fail on purpose)
                          (= 200 (res :status)))
                        (fn [err]
                          (assert false "will not reach here"))))
      # exception while request
      (assert (:enqueue queue
                        (new-request :get "malformed-url")
                        (fn [res]
                          (assert false "should not reach here")) 
                        (fn [_]
                          true)
                        (fn [err]
                          (assert err "should reach here")
                          
                          (ev/give ch 2))))
      (assert (:enqueue queue
                        (new-request :get "https://postman-echo.com/delay/4")
                        (fn [res]
                          (assert res)

                          (ev/give ch 3))))
      (assert (:enqueue queue
                        (new-request :get "https://postman-echo.com/delay/3")
                        (fn [res]
                          (assert res)
                                    
                          (ev/give ch 4))))
      (assert (:enqueue queue
                        (new-request :get "https://postman-echo.com/delay/2")
                        (fn [res]
                          (assert res)
                                    
                          (ev/give ch 5))))
      (assert (:enqueue queue
                        (new-request :get "https://postman-echo.com/delay/1")
                        (fn [res]
                          (assert res)
                                    
                          (ev/give ch 6))))))

  # all requests will be processed in the sequence they were enqueued
  (assert (= (ev/take ch) 0))
  (assert (= (ev/take ch) 1))
  (assert (= (ev/take ch) 2))
  (assert (= (ev/take ch) 3))
  (assert (= (ev/take ch) 4))
  (assert (= (ev/take ch) 5))
  (assert (= (ev/take ch) 6))
  
  # close the queue
  (assert (:close queue)))
