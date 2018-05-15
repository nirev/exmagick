/* Copyright (c) 2015, Diego Souza
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 *
 * 3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#include "erl_nif.h"
#include <magick/api.h>
#include <stdio.h>
#include <string.h>
#include <langinfo.h>

#define EXM_MAX_ATOM_SIZE 255
#define EXM_INIT char *errmsg = NULL
#define EXM_FAIL(j, m) do { errmsg = m; goto j; } while (0)

typedef struct {
  Image *image;
  ImageInfo *i_info;
  ExceptionInfo e_info;
} exm_resource_t;

static int    exmagick_load          (ErlNifEnv *env, void **data, ERL_NIF_TERM info);
static void   exmagick_unload        (ErlNifEnv *env, void *data);
static void   exmagick_destroy       (ErlNifEnv *env, void *data);
static char  *exmagick_utf8strcpy    (char *dst, ErlNifBinary *utf8, size_t len);
static int    exmagick_get_utf8str   (ErlNifEnv *env, ERL_NIF_TERM arg, ErlNifBinary *utf8);
static int    exmagick_get_boolean_u (ErlNifEnv *env, ERL_NIF_TERM arg, unsigned int *p);

static ERL_NIF_TERM exmagick_make_utf8str (ErlNifEnv *env, const char *data);

static ERL_NIF_TERM exmagick_crop            (ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]);
static ERL_NIF_TERM exmagick_set_attr        (ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]);
static ERL_NIF_TERM exmagick_get_attr        (ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]);
static ERL_NIF_TERM exmagick_set_size        (ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]);
static ERL_NIF_TERM exmagick_num_pages       (ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]);
static ERL_NIF_TERM exmagick_init_handle     (ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]);
static ERL_NIF_TERM exmagick_image_thumb     (ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]);
static ERL_NIF_TERM exmagick_image_load_file (ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]);
static ERL_NIF_TERM exmagick_image_load_blob (ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]);
static ERL_NIF_TERM exmagick_image_dump_file (ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]);
static ERL_NIF_TERM exmagick_image_dump_blob (ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]);
static ERL_NIF_TERM exmagick_convert         (ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]);

#ifdef EXM_NO_DIRTY_SCHED
ErlNifFunc exmagick_interface[] =
{
  {"init", 0, exmagick_init_handle},
  {"image_load_blob", 2, exmagick_image_load_blob},
  {"image_load_file", 2, exmagick_image_load_file},
  {"image_dump_file", 2, exmagick_image_dump_file},
  {"image_dump_blob", 1, exmagick_image_dump_blob},
  {"set_attr", 3, exmagick_set_attr},
  {"get_attr", 2, exmagick_get_attr},
  {"thumb", 3, exmagick_image_thumb},
  {"size", 3, exmagick_set_size},
  {"num_pages", 1, exmagick_num_pages},
  {"crop", 5, exmagick_crop},
  {"convert", 3, exmagick_convert}
};
#else
ErlNifFunc exmagick_interface[] =
{
  {"init", 0, exmagick_init_handle, 0},
  {"image_load_blob", 2, exmagick_image_load_blob, ERL_NIF_DIRTY_JOB_CPU_BOUND},
  {"image_load_file", 2, exmagick_image_load_file, ERL_NIF_DIRTY_JOB_CPU_BOUND},
  {"image_dump_file", 2, exmagick_image_dump_file, ERL_NIF_DIRTY_JOB_CPU_BOUND},
  {"image_dump_blob", 1, exmagick_image_dump_blob, ERL_NIF_DIRTY_JOB_CPU_BOUND},
  {"set_attr", 3, exmagick_set_attr, ERL_NIF_DIRTY_JOB_CPU_BOUND},
  {"get_attr", 2, exmagick_get_attr, ERL_NIF_DIRTY_JOB_CPU_BOUND},
  {"thumb", 3, exmagick_image_thumb, ERL_NIF_DIRTY_JOB_CPU_BOUND},
  {"size", 3, exmagick_set_size, ERL_NIF_DIRTY_JOB_CPU_BOUND},
  {"num_pages", 1, exmagick_num_pages, ERL_NIF_DIRTY_JOB_CPU_BOUND},
  {"crop", 5, exmagick_crop, ERL_NIF_DIRTY_JOB_CPU_BOUND},
  {"convert", 3, exmagick_convert, ERL_NIF_DIRTY_JOB_CPU_BOUND}
};
#endif

ERL_NIF_INIT(Elixir.ExMagick, exmagick_interface, exmagick_load, NULL, NULL, exmagick_unload)

/**
 * Initializes the module once per VM
 * - creates a new type name "ExMagick"
 * - starts GraphicMagick
 */
static
int exmagick_load (ErlNifEnv *env, void **data, const ERL_NIF_TERM info)
{
  void *type = enif_open_resource_type(env, "Elixir", "ExMagick", exmagick_destroy, ERL_NIF_RT_CREATE, NULL);
  if (type == NULL)
  { return(-1); }
  InitializeMagick(NULL);
  *data = type;
  return(0);
}

static
int exmagick_get_boolean_u (ErlNifEnv *env, ERL_NIF_TERM arg, unsigned int *p)
{
  int ecode;
  char atom[EXM_MAX_ATOM_SIZE];
  if (0 != (ecode = enif_get_atom(env, arg, atom, EXM_MAX_ATOM_SIZE, ERL_NIF_LATIN1)))
  {
    if (strcmp("true", atom) == 0)
    { *p = 1; }
    else if (strcmp("false", atom) == 0)
    { *p = 0; }
    else
    { ecode = 0; }
  }

  return(ecode);
}

static
int exmagick_get_double (ErlNifEnv *env, ERL_NIF_TERM arg, double *dbl)
{
  int ecode;
  char atom[EXM_MAX_ATOM_SIZE];

  ecode = enif_get_double(env, arg, dbl);

  return(ecode);
}

static
void exmagick_destroy (ErlNifEnv *env, void *data)
{
  exm_resource_t *resource = (exm_resource_t *) data;
  if (resource->image != NULL)
  { DestroyImage(resource->image); }

  if (resource->i_info != NULL)
  { DestroyImageInfo(resource->i_info); }

  resource->image  = NULL;
  resource->i_info = NULL;
}

static
void exmagick_unload (ErlNifEnv *env, void *priv_data)
{}

static
char *exmagick_utf8strcpy (char *dst, ErlNifBinary *utf8, size_t size)
{
  size_t rsize = utf8->size >= size ? size - 1 : utf8->size;
  memcpy(dst, utf8->data, rsize);
  dst[rsize] = '\0';
  return dst;
}

/*
  The string returned in this function must be freed using MagickFree.
 */
static
char *exmagick_utf8strdup (ErlNifBinary *utf8)
{
  char *dst = MagickMalloc(utf8->size + 1);
  if (dst == NULL) { return NULL; }
  return exmagick_utf8strcpy(dst, utf8, utf8->size + 1);
}

static
ERL_NIF_TERM exmagick_make_utf8str (ErlNifEnv *env, const char *data)
{
  ErlNifBinary utf8;

  size_t datalen = data == NULL ? 0 : strlen(data); /* TODO:strlen is wrong */
  if (0 == enif_alloc_binary(datalen, &utf8))
  { return(enif_make_badarg(env)); } /* XXX: use enif_raise_exception or a better way to report a memory error */

  memcpy(utf8.data, data, datalen);
  return(enif_make_binary(env, &utf8));
}

static
int exmagick_get_utf8str (ErlNifEnv *env, const ERL_NIF_TERM arg, ErlNifBinary *utf8)
{ return(enif_inspect_binary(env, arg, utf8)); }

static
ERL_NIF_TERM exmagick_init_handle (ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
  ERL_NIF_TERM result;

  EXM_INIT;
  ErlNifResourceType *type = (ErlNifResourceType *) enif_priv_data(env);
  exm_resource_t *resource = enif_alloc_resource(type, sizeof(exm_resource_t));
  if (resource == NULL)
  { EXM_FAIL(ehandler, "enif_alloc_resource"); }

  /* initializes exception to default values (badly named function) */
  GetExceptionInfo(&resource->e_info);

  resource->image  = NULL;
  resource->i_info = CloneImageInfo(0);
  if (resource->i_info == NULL)
  { EXM_FAIL(ehandler, "CloneImageInfo"); }

  result = enif_make_resource(env, (void *) resource);
  enif_release_resource(resource);
  return(enif_make_tuple2(env, enif_make_atom(env, "ok"), result));

ehandler:
  if (resource != NULL)
  {
    if (resource->i_info != NULL)
    { DestroyImageInfo(resource->i_info); }
    enif_release_resource(resource);
  }
  return(enif_make_tuple2(env, enif_make_atom(env, "error"), exmagick_make_utf8str(env, errmsg)));
}

static
ERL_NIF_TERM exmagick_set_size (ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
  long width, height;
  Image* resized_image;
  exm_resource_t *resource;

  EXM_INIT;
  ErlNifResourceType *type = (ErlNifResourceType *) enif_priv_data(env);

  if (0 == enif_get_resource(env, argv[0], type, (void **) &resource))
  { EXM_FAIL(ehandler, "invalid handle"); }

  if (resource->image == NULL)
  { EXM_FAIL(ehandler, "image not loaded"); }

  if (0 == enif_get_long(env, argv[1], &width))
  { EXM_FAIL(ehandler, "width: bad argument"); }

  if (0 == enif_get_long(env, argv[2], &height))
  { EXM_FAIL(ehandler, "height: bad argument"); }

  resized_image = ScaleImage(resource->image, width, height, &resource->e_info);
  if (resized_image == NULL)
  {
    CatchException(&resource->e_info);
    EXM_FAIL(ehandler, resource->e_info.reason);
  }
  DestroyImage(resource->image);
  resource->image = resized_image;

  return(enif_make_tuple2(env, enif_make_atom(env, "ok"), argv[0]));

ehandler:
  return(enif_make_tuple2(env, enif_make_atom(env, "error"), exmagick_make_utf8str(env, errmsg)));
}

static
ERL_NIF_TERM exmagick_num_pages (ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
  exm_resource_t *resource;
  Image* image;
  int num_pages;

  EXM_INIT;
  ErlNifResourceType *type = (ErlNifResourceType *) enif_priv_data(env);

  if (0 == enif_get_resource(env, argv[0], type, (void **) &resource))
  { EXM_FAIL(ehandler, "invalid handle"); }

  if (resource->image == NULL)
  { EXM_FAIL(ehandler, "image not loaded"); }

  image = resource->image;
  num_pages = 1;

  while((image = image->next))
  { ++num_pages; }

  return(enif_make_tuple2(env, enif_make_atom(env, "ok"), enif_make_int(env, num_pages)));

ehandler:
  return(enif_make_tuple2(env, enif_make_atom(env, "error"), exmagick_make_utf8str(env, errmsg)));
}

static
ERL_NIF_TERM exmagick_crop (ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
  Image* cropped_image;
  RectangleInfo rect;
  exm_resource_t *resource;

  EXM_INIT;
  ErlNifResourceType *type = (ErlNifResourceType *) enif_priv_data(env);

  if (0 == enif_get_resource(env, argv[0], type, (void **) &resource))
  { EXM_FAIL(ehandler, "invalid handle"); }

  if (resource->image == NULL)
  { EXM_FAIL(ehandler, "image not loaded"); }

  /* build rectangle */
  if (0 == enif_get_long(env, argv[1], &rect.x))
  { EXM_FAIL(ehandler, "x0: bad argument"); }

  if (0 == enif_get_long(env, argv[2], &rect.y))
  { EXM_FAIL(ehandler, "y0: bad argument"); }

  if (0 == enif_get_ulong(env, argv[3], &rect.width))
  { EXM_FAIL(ehandler, "width: bad argument"); }

  if (0 == enif_get_ulong(env, argv[4], &rect.height))
  { EXM_FAIL(ehandler, "height: bad argument"); }

  /* actually crops image */
  cropped_image = CropImage(resource->image, &rect, &resource->e_info);
  if (cropped_image == NULL)
  {
    CatchException(&resource->e_info);
    EXM_FAIL(ehandler, resource->e_info.reason);
  }
  DestroyImage(resource->image);
  resource->image = cropped_image;

  return(enif_make_tuple2(env, enif_make_atom(env, "ok"), argv[0]));

ehandler:
  return(enif_make_tuple2(env, enif_make_atom(env, "error"), exmagick_make_utf8str(env, errmsg)));
}

static
ERL_NIF_TERM exmagick_image_thumb (ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
  long width, height;
  Image* thumb;
  exm_resource_t *resource;

  EXM_INIT;
  ErlNifResourceType *type = (ErlNifResourceType *) enif_priv_data(env);

  if (0 == enif_get_resource(env, argv[0], type, (void **) &resource))
  { EXM_FAIL(ehandler, "invalid handle"); }

  if (resource->image == NULL)
  { EXM_FAIL(ehandler, "image not loaded"); }

  if (0 == enif_get_long(env, argv[1], &width))
  { EXM_FAIL(ehandler, "width: bad argument"); }

  if (0 == enif_get_long(env, argv[2], &height))
  { EXM_FAIL(ehandler, "height: bad argument"); }

  thumb = ThumbnailImage(resource->image, width, height, &resource->e_info);
  if (thumb == NULL)
  {
    CatchException(&resource->e_info);
    EXM_FAIL(ehandler, resource->e_info.reason);
  }
  DestroyImage(resource->image);
  resource->image = thumb;

  return(enif_make_tuple2(env, enif_make_atom(env, "ok"), argv[0]));

ehandler:
  return(enif_make_tuple2(env, enif_make_atom(env, "error"), exmagick_make_utf8str(env, errmsg)));
}

static
ERL_NIF_TERM exmagick_set_attr (ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
  ErlNifBinary utf8;
  char atom[EXM_MAX_ATOM_SIZE];
  exm_resource_t *resource;

  EXM_INIT;
  ErlNifResourceType *type = (ErlNifResourceType *) enif_priv_data(env);

  if (0 == enif_get_resource(env, argv[0], type, (void **) &resource))
  { EXM_FAIL(ehandler, "invalid handle"); }

  if (0 == enif_get_atom(env, argv[1], atom, EXM_MAX_ATOM_SIZE, ERL_NIF_LATIN1))
  { EXM_FAIL(ehandler, "argv[1]: bad argument"); }

  if (strcmp("adjoin", atom) == 0)
  {
    if (0 == exmagick_get_boolean_u(env, argv[2], &resource->i_info->adjoin))
    { EXM_FAIL(ehandler, "argv[2]: bad argument"); }
  }
  if (strcmp("magick", atom) == 0)
  {
    if (0 == exmagick_get_utf8str(env, argv[2], &utf8))
    { EXM_FAIL(ehandler, "argv[2]: bad argument"); }
    exmagick_utf8strcpy(resource->image->magick, &utf8, MaxTextExtent);
  }
  if (strcmp("density", atom) == 0)
  {
    if (0 == exmagick_get_utf8str(env, argv[2], &utf8))
    { EXM_FAIL(ehandler, "argv[2]: bad argument"); }
    MagickFree(resource->i_info->density);
    resource->i_info->density=exmagick_utf8strdup(&utf8);
    if (resource->i_info->density == NULL)
    { EXM_FAIL(ehandler, "could not set density"); }
  }

  return(enif_make_tuple2(env, enif_make_atom(env, "ok"), argv[0]));

ehandler:
  return(enif_make_tuple2(env, enif_make_atom(env, "error"), exmagick_make_utf8str(env, errmsg)));
}

ERL_NIF_TERM exmagick_get_attr (ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
  char atom[EXM_MAX_ATOM_SIZE];
  exm_resource_t *resource;

  EXM_INIT;
  ErlNifResourceType *type = (ErlNifResourceType *) enif_priv_data(env);

  if (0 == enif_get_resource(env, argv[0], type, (void **) &resource))
  { EXM_FAIL(ehandler, "invalid handle"); }

  if (0 == enif_get_atom(env, argv[1], atom, EXM_MAX_ATOM_SIZE, ERL_NIF_LATIN1))
  { EXM_FAIL(ehandler, "invalid attribute"); }

  if (strcmp("adjoin", atom) == 0)
  {
    if (resource->i_info->adjoin == 0)
    { return(enif_make_tuple2(env, enif_make_atom(env, "ok"), enif_make_atom(env, "false"))); }
    else if (resource->i_info->adjoin == 1)
    { return(enif_make_tuple2(env, enif_make_atom(env, "ok"), enif_make_atom(env, "true"))); }
  }
  if (strcmp("rows", atom) == 0)
  {
    if (resource->image == NULL)
    { EXM_FAIL(ehandler, "image not loaded"); }

    { return(enif_make_tuple2(env, enif_make_atom(env, "ok"), enif_make_long(env, resource->image->rows))); }
  }
  if (strcmp("columns", atom) == 0)
  {
    if (resource->image == NULL)
    { EXM_FAIL(ehandler, "image not loaded"); }

    { return(enif_make_tuple2(env, enif_make_atom(env, "ok"), enif_make_long(env, resource->image->columns))); }
  }
  if (strcmp("density", atom) == 0)
  { return(enif_make_tuple2(env, enif_make_atom(env, "ok"), exmagick_make_utf8str(env, resource->i_info->density))); }
  else if (strcmp("magick", atom) == 0)
  { return(enif_make_tuple2(env, enif_make_atom(env, "ok"), exmagick_make_utf8str(env, resource->image->magick))); }

ehandler:
  return(enif_make_tuple2(env, enif_make_atom(env, "error"), exmagick_make_utf8str(env, errmsg)));
}

static
ERL_NIF_TERM exmagick_image_load_blob (ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
  ErlNifBinary blob;
  exm_resource_t *resource;

  EXM_INIT;
  ErlNifResourceType *type = (ErlNifResourceType *) enif_priv_data(env);

  if (0 == enif_get_resource(env, argv[0], type, (void **) &resource))
  { EXM_FAIL(ehandler, "invalid handle"); }

  if (0 == enif_inspect_binary(env, argv[1], &blob))
  { EXM_FAIL(ehandler, "argv[1]: bad argument"); }

  if (resource->image != NULL)
  {
    DestroyImage(resource->image);
    resource->image = NULL;
  }

  resource->image = BlobToImage(resource->i_info, blob.data, blob.size, &resource->e_info);
  if (resource->image == NULL)
  {
    CatchException(&resource->e_info);
    EXM_FAIL(ehandler, resource->e_info.reason);
  }

  return(enif_make_tuple2(env, enif_make_atom(env, "ok"), argv[0]));

ehandler:
  return(enif_make_tuple2(env, enif_make_atom(env, "error"), exmagick_make_utf8str(env, errmsg)));
}

static
ERL_NIF_TERM exmagick_image_load_file (ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
  ErlNifBinary utf8;
  exm_resource_t *resource;

  EXM_INIT;
  ErlNifResourceType *type = (ErlNifResourceType *) enif_priv_data(env);

  if (0 == enif_get_resource(env, argv[0], type, (void **) &resource))
  { EXM_FAIL(ehandler, "invalid handle"); }

  if (0 == exmagick_get_utf8str(env, argv[1], &utf8))
  { EXM_FAIL(ehandler, "argv[1]: bad argument"); }

  exmagick_utf8strcpy(resource->i_info->filename, &utf8, MaxTextExtent);
  if (resource->image != NULL)
  {
    DestroyImage(resource->image);
    resource->image = NULL;
  }

  resource->image = ReadImage(resource->i_info, &resource->e_info);
  if (resource->image == NULL)
  {
    CatchException(&resource->e_info);
    EXM_FAIL(ehandler, resource->e_info.reason);
  }

  return(enif_make_tuple2(env, enif_make_atom(env, "ok"), argv[0]));

ehandler:
  return(enif_make_tuple2(env, enif_make_atom(env, "error"), exmagick_make_utf8str(env, errmsg)));
}

static
ERL_NIF_TERM exmagick_image_dump_file (ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
  char filename[MaxTextExtent];
  ErlNifBinary utf8;
  exm_resource_t *resource;

  EXM_INIT;
  ErlNifResourceType *type = (ErlNifResourceType *) enif_priv_data(env);

  if (0 == enif_get_resource(env, argv[0], type, (void **) &resource))
  { EXM_FAIL(ehandler, "invalid handle"); }

  if (0 == exmagick_get_utf8str(env, argv[1], &utf8))
  { EXM_FAIL(ehandler, "argv[1]: bad argument"); }

  exmagick_utf8strcpy (filename, &utf8, MaxTextExtent);
  if (0 == WriteImages(resource->i_info, resource->image, filename, &resource->e_info))
  {
    CatchException(&resource->e_info);
    EXM_FAIL(ehandler, resource->e_info.reason);
  }

  return(enif_make_tuple2(env, enif_make_atom(env, "ok"), argv[0]));

ehandler:
  return(enif_make_tuple2(env, enif_make_atom(env, "error"), exmagick_make_utf8str(env, errmsg)));
}

static
ERL_NIF_TERM exmagick_image_dump_blob (ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
  void *blob_image = NULL;
  size_t size;
  exm_resource_t *resource;
  ERL_NIF_TERM blob_term;
  unsigned char *blob_raw;

  EXM_INIT;
  ErlNifResourceType *type = (ErlNifResourceType *) enif_priv_data(env);

  if (0 == enif_get_resource(env, argv[0], type, (void **) &resource))
  { EXM_FAIL(ehandler, "invalid handle"); }

  blob_image = ImageToBlob(resource->i_info, resource->image, &size, &resource->e_info);
  if (NULL == blob_image)
  {
    CatchException(&resource->e_info);
    EXM_FAIL(ehandler, resource->e_info.reason);
  }

  blob_raw = enif_make_new_binary(env, size, &blob_term);
  if (NULL == blob_raw)
  { EXM_FAIL(ehandler, "enif_make_new_binary error"); }

  memcpy(blob_raw, blob_image, size);
  MagickFree(blob_image);

  return(enif_make_tuple2(env, enif_make_atom(env, "ok"), blob_term));
ehandler:
  if (NULL != blob_image)
  { MagickFree(blob_image); }
  return(enif_make_tuple2(env, enif_make_atom(env, "error"), exmagick_make_utf8str(env, errmsg)));
}

static
ERL_NIF_TERM exmagick_convert (ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
  ErlNifBinary utf8;
  char atom[EXM_MAX_ATOM_SIZE];
  exm_resource_t *resource;

  EXM_INIT;
  ErlNifResourceType *type = (ErlNifResourceType *) enif_priv_data(env);

  if (0 == enif_get_resource(env, argv[0], type, (void **) &resource))
  { EXM_FAIL(ehandler, "invalid handle"); }
  if (0 == enif_get_atom(env, argv[1], atom, EXM_MAX_ATOM_SIZE, ERL_NIF_LATIN1))
  { EXM_FAIL(ehandler, "argv[1]: bad argument"); }

  if (strcmp("black_threshold_image", atom) == 0)
  {
    char str_value[MaxTextExtent];

    if (0 == exmagick_get_utf8str(env, argv[2], &utf8))
    { EXM_FAIL(ehandler, "argv[2]: bad argument"); }

    exmagick_utf8strcpy(str_value, &utf8, MaxTextExtent);

    if (0 == BlackThresholdImage(resource->image, &str_value))
    { EXM_FAIL(ehandler, "failed to apply BlackThresholdImage"); }
  }

  if (strcmp("threshold_image", atom) == 0)
  {
    double dbl_value;

    if (0 == exmagick_get_double(env, argv[2], &dbl_value))
    { EXM_FAIL(ehandler, "argv[2]: bad argument"); }

    if (0 == ThresholdImage(resource->image, dbl_value))
    { EXM_FAIL(ehandler, "failed to apply ThresholdImage"); }
  }

  if (strcmp("white_threshold_image", atom) == 0)
  {
    char str_value[MaxTextExtent];
 
    if (0 == exmagick_get_utf8str(env, argv[2], &utf8))
    { EXM_FAIL(ehandler, "argv[2]: bad argument"); }

    exmagick_utf8strcpy(str_value, &utf8, MaxTextExtent);

    if (0 == WhiteThresholdImage(resource->image, &str_value))
    { EXM_FAIL(ehandler, "failed to apply WhiteThresholdImage"); }
  }

  return(enif_make_tuple2(env, enif_make_atom(env, "ok"), argv[0]));

ehandler:
  return(enif_make_tuple2(env, enif_make_atom(env, "error"), exmagick_make_utf8str(env, errmsg)));
}
