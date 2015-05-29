var gulp = require('gulp');
var coffee = require('gulp-coffee');
var uglify = require('gulp-uglify');
var concat = require('gulp-concat');
var sourcemaps = require('gulp-sourcemaps');
var del = require('del');
var webserver = require('gulp-webserver');

var path_scripts = './src/*.coffee';

// Not all tasks need to use streams
// A gulpfile is just another node program and you can use all packages available on npm
gulp.task('clean', function(cb) {
  // You can use multiple globbing patterns as you would with `gulp.src`
  del(['build'], cb);
});

gulp.task('preview', function() {
  gulp.src('.')
    .pipe(webserver({
      livereload: true,
      directoryListing: true,
      open: "http://localhost:8000/index.html"
    }));
});

gulp.task('scripts', ['clean'], function() {
  // Minify and copy all JavaScript (except vendor scripts)
  // with sourcemaps all the way down
  return gulp.src(path_scripts)
    .pipe(sourcemaps.init())
      .pipe(coffee({ bare: true }))
      // .pipe(uglify())
      .pipe(concat('threesixty.min.js'))
    .pipe(sourcemaps.write())
    .pipe(gulp.dest('build/'));
});

gulp.task('watch', function() {
  gulp.watch(path_scripts, ['scripts']);
});

gulp.task('default', ['scripts', 'preview', 'watch']);
