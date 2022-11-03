# src/queue.janet
#
# Things for queueing and executing requests sequentially.
#
# created on : 2022.11.03.
# last update: 2022.11.03.

(import ./request)

(def- default-num-retries 3)

# prototype for queue
(def Queue
  @{:max-retries 0

    #channels
    :ch nil

    # prototype functions
    :enqueue nil
    :close nil})

(defn- process
  ``Processes (recursively) requests, synchronously.
  ``
  [queue req retrying-count fn-on-response fn-success? fn-on-error fn-retry?]

  (try
    (do
      # execute request,
      (let [response (:execute req)]
        (if (fn-success? response)
          # on success, callback response
          (do
            (fn-on-response response))
          # on error,
          (do
            (if (fn-retry? response)
              # if it is retryable,
              (if (< retrying-count (queue :max-retries))
                # retry if limit count not reached,
                (process queue req (inc retrying-count) fn-on-response fn-success? fn-on-error fn-retry?)
                # or just pass the error
                (fn-on-response response))
              # do not retry, just pass the error
              (fn-on-response response))))))
    ([err] (do
             # callback exception
             (fn-on-error {:status -1
                           :error err})))))

(defn enqueue
  ``Enqueues given `req` to `queue`.
  When it was successful, returns `req` immediately.
  When it failed, returns nil.

  When `fn-success?' is given, it will tell if the response was successful or not.
  It takes the http response as a parameter, and returns if it was successful or not.
  If it is nil, response will be considered succcessful only when its http status code is 200.

  When `fn-on-error` is given and request fails with error, the error will be passed to it.
  If it is nil, it will be printed to stdout.

  When `fn-retry?` is given, it will tell if the request should be retried or not.
  If `fn-success?` returns false, and `fn-retry?` returns true, `req` will be executed again.
  If it is nil, there will be no retry.

  After all the retries, the last http response will be passed to `fn-on-response`.
  If there was any unrecoverable error with requests, `fn-on-error` may have been called already,
  and in that case `fn-on-response` will not be called.
  ``
  [queue req fn-on-response &opt fn-success? fn-on-error fn-retry?]

  (default fn-success? (fn [res] (= 200 (res :status))))
  (default fn-on-error (fn [err] (print (string/format "on-error: %s" err))))
  (default fn-retry? (fn [_] false))

  (var ret nil)

  (try
    (do
      (ev/give (queue :ch) {:request req
                            :on-response fn-on-response
                            :success? fn-success?
                            :on-error fn-on-error
                            :retry? fn-retry?})
      (set ret req))
    ([err] (do
             (print (string/format "failed to enqueue request: %m" err)))))

  ret)

(defn close
  ``Closes given `queue`.
  ``
  [queue]

  # close channels
  (ev/chan-close (queue :ch)))

(defn new-queue
  ``Creates and returns a new request queue.

  Created queue will start a long-running thread that will poll enqueued requests from its channel.

  It needs to be `close`d when not in use.
  ``
  [&opt max-retries]

  (default max-retries default-num-retries)

  (let [queue (table/setproto @{:max-retries max-retries

                                :ch (ev/thread-chan)

                                :enqueue enqueue
                                :close close}
                              Queue)
        ch (queue :ch)]
    # start a thread for processing enqueued items
    (ev/spawn-thread
      (do
        (forever
          (if-let [selected (ev/select ch)]
            (do
              (match selected
                # got a value,
                [:take _ v]
                (do
                  # process it,
                  (let [req (v :request)
                        fn-on-response (v :on-response) 
                        fn-success? (v :success?)
                        fn-on-error (v :on-error)
                        fn-retry? (v :on-retry?)]
                    (process queue req 0 fn-on-response fn-success? fn-on-error fn-retry?)))

                # if selected value is not valid, stop the loop
                _
                (do
                  (break))))
            # if ev/select fails, stop the loop
            (break)))))

    queue))
