;; sflow/empty : () -> stream
;; Returns an empty stream.
(define (sflow/empty)
  (define (empty) '())
  (vector #t '() empty))


;; sflow/make-stream : (() -> any) -> stream
;; Creates a new stream by repeatedly calling a generator function to produce
;; the stream's elements.
(define (sflow/make-stream generator)
  (define (new-generator) (list (generator)))
  (vector #f '() new-generator))


;; sflow/list->stream : (list any) -> stream
;; Takes a list of values and returns a stream containing those values.
(define (sflow/list->stream . values)
  (define head '())
  (define rest values)
  (define (next)
    (if (null? rest)
	'()
	(begin
	  (set! head (car rest))
	  (set! rest (cdr rest))
	  (list head))))
  (vector #t '() next))


;; sflow/iterate : any (any -> any) -> stream
;; Creates a new stream that iterates over a seed value using an update function. The first
;; element of the stream will be the seed value, and subsequent elements will be produced
;; by repeatedly applying the update function to the previous element. The resulting stream
;; will be infinite and will contain the values produced by the update function, in the order
;; in which they were produced.
(define (sflow/iterate seed update)
  (define seed seed)
  (define (new-udpate)
    (set! seed (update seed))
    (list seed))
  (vector #f seed new-update))


;; sflow/iterate : integer integer -> stream
;; Creates a stream of numbers from lower to upper (inclusive).
(define (sflow/sequence lower upper)
  (define value lower)
  (define (next)
    (if (<= value upper)
	(let ((x value))
	  (begin
	    (set! value (+ value 1))
	    (list x)))
	'()))
  (if (> lower upper)
      (sflow/sequence upper lower)
      (vector #t '() next)))


;; sflow/iterate : integer integer integer -> stream
;; Creates a stream of n evenly spaced numbers between lower and upper (inclusive).
(define (sflow/linspace lower upper n)
  (define i 0)
  (define value lower)
  (define step
    (exact->inexact (/ (- upper lower) n)))
  (define (next)
    (if (<= i n)
	(let ((x value))
	  (begin
	    (set! i (+ i 1))
	    (set! value (+ value step))
	    (list x)))
	'()))
  (if (> lower upper)
      (sflow/sequence upper lower)
      (vector #t '() next)))


;; sflow/peek : stream -> (list any)
;; Consumes the next element from a stream and returns it, but also caches the element
;; so that it can be accessed again later without advancing the stream.
(define (sflow/peek stream)
  (define head (vector-ref stream 1))
  (define next (vector-ref stream 2))
  (define (peek)
    (if (null? head)
	(let ((new-head (next)))
	  (vector-set! stream 1 new-head)
	  new-head)
	head))
  (peek))


;; sflow/next : stream -> (list any)
;; Returns the next element from a stream wrapped in list,
;; advancing the stream by one element. If the stream is empty,
;; `sflow/next` will return an empty list.
(define (sflow/next stream)
  (define head (vector-ref stream 1))
  (define next (vector-ref stream 2))
  (if (null? head)
      (next)
      (begin
	(vector-set! stream 1 '())
	head)))


;; sflow/is-bounded? : stream -> boolean
;; Determines whether a stream is bounded (i.e., has a finite number of elements) or infinite.
;; Returns `#t` if the stream is bounded and `#f` if the stream is infinite.
(define (sflow/is-bounded? stream)
  (vector-ref stream 0))


;; sflow/concat : (list stream) -> stream
;; Concatenates the input streams into a single stream, in the order they are passed in.
(define (sflow/concat . streams)
  (define is-bounded? #t)
  (define head-stream '())
  (define tail-stream streams)
  (define (on-stream-unbounded)
    (set! tail-stream '()))
  (define (on-stream-end)
    (set! head-stream '()))
  (define (on-stream-empty)
    (when (not (null? tail-stream))
      (begin
	(set! head-stream (car tail-stream))
	(set! tail-stream (cdr tail-stream))
	(set! is-bounded? (and is-bounded? (sflow/is-bounded? head-stream)))
	(when (not is-bounded?)
	  (on-stream-unbounded)))))
  (define (next)
    (if (null? head-stream)
	(begin
	  (on-stream-empty)
	  (if (null? head-stream) '() (next)))
	(let ((head (sflow/next head-stream)))
	  (if (null? head)
	      (begin
		(on-stream-end)
		(next))
	      head))))
  (vector is-bounded? '() next))


;; sflow/until : (any -> boolean) -> stream
;; Returns a new stream that contains all the elements of the input stream until the
;; condition function returns true for an element.
(define (sflow/until end? stream)
  (define continue? #t)
  (define (on-close)
    (set! continue? #f))
  (define (until value)
    (if continue?
	(if (end? (car value))
	    (begin
	      (on-close)
	      '())
	    value)
	'()))
  (define (next)
    (let ((value (sflow/next stream)))
      (if (null? value)
	  '()
	  (until value))))
  (vector #t '() next))


;; sflow/filter : (any -> boolean) -> stream
;; Returns a new stream that contains only the elements of the input stream for which
;; the keep? function returns true.
(define (sflow/filter keep? stream)
  (define (next)
    (let ((value (sflow/next stream)))
      (if (null? value)
	  '()
	  (if (keep? (car value)) value (next)))))
  (vector (sflow/is-bounded? stream) '() next))


;; sflow/take : integer stream -> stream
;; Returns a new stream that contains the first n elements of the input stream.
(define (sflow/take n stream)
  (define i 0)
  (define (on-next)
    (set! i (+ i 1)))
  (define (on-take _)
    (on-next)
    (> i n))
  (sflow/until on-take stream))


;; sflow/drop : integer stream -> stream
;; Returns a new stream that contains all elements of the input stream after
;; the first n elements.
(define (sflow/drop n stream)
  (define i 0)
  (define (on-next)
    (set! i (+ i 1)))
  (define (on-drop _)
    (on-next)
    (> i n))
  (sflow/filter on-drop stream))


;; sflow/map : (any -> any) stream -> stream
;; Returns a new stream that contains the result of applying the function `f` to
;; each element of the input stream.
(define (sflow/map f stream)
  (define (next)
    (map f (sflow/next stream)))
  (vector (sflow/is-bounded? stream) '() next))


;; sflow/flatmap : (any -> any) stream -> stream
;; Returns a new stream that contains the result of applying the function `f` to
;; each element of the input stream.
(define (sflow/flatmap f stream)
  (define streams (sflow/map f stream))
  (define current-stream (sflow/next streams))
  (define (on-current-stream-end)
    (set! current-stream (sflow/next streams)))
  (define (next)
    (if (not (null? current-stream))
	(if (sflow/is-bounded? (car current-stream))
	    (let ((value (sflow/next (car current-stream))))
	      (if (not (null? value))
		  value
		  (begin
		    (on-current-stream-end)
		    (next))))
	    '())
	'()))
  (if (sflow/is-bounded? streams)
      (vector #t '() next)
      (sflow/empty)))


;; sflow/foldl : any (any any -> any) stream -> any
;; Applies the function `update` to each element of the input stream `stream`,
;; accumulating the result in a variable initialized with `seed`. The final
;; accumulated value is returned.
(define (sflow/foldl seed update stream)
  (define (consume-stream seed)
    (let ((value (sflow/next stream)))
      (if (null? value)
	  seed
	  (consume-stream (update seed (car value))))))
  (if (sflow/is-bounded? stream)
      (consume-stream seed)
      seed))


;; sflow/count : stream -> integer
;; Returns the number of elements in the input stream `stream`.
(define (sflow/count stream)
  (define (count seed value)
    (+ seed 1))
  (sflow/foldl 0 count stream))


;; sflow/first : stream -> (list any)
;; Returns the first of element in the input stream `stream`.
(define (sflow/first stream)
  (sflow/next stream))


;; sflow/last : stream -> (list any)
;; Returns the last of element in the input stream `stream`.
(define (sflow/last stream)
  (define (last previous)
    (let ((value (sflow/next stream)))
      (if (null? value)
	  previous
	  (last value))))
  (last '()))


;; sflow/min : stream -> (list any)
;; Finds the minimum value in a stream.
(define (sflow/min stream)
  (define (update seed value)
    (if (< value seed)
	value
	seed))
  (let ((value (sflow/next stream)))
    (if (null? value)
	'()
	(list (sflow/foldl (car value) update stream)))))


;; sflow/max : stream -> (list any)
;; Finds the maximum value in a stream.
(define (sflow/max stream)
  (define (update seed value)
    (if (> value seed)
	value
	seed))
  (let ((value (sflow/next stream)))
    (if (null? value)
	'()
	(list (sflow/foldl (car value) update stream)))))


;; sflow/stream->list : stream -> (list any)
;; Converts a stream into a list.
(define (sflow/stream->list stream)
  (define (update values value)
    (cons value values))
  (reverse (sflow/foldl '() update stream)))
